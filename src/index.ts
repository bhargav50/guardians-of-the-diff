import { randomUUID } from "node:crypto"
import { appendFile, mkdir } from "node:fs/promises"
import { dirname } from "node:path"
import { Plugin } from "@opencode/plugin"
import {
  buildEvaluationPrompt,
  clip,
  humanEditDecision,
  parseEvaluatorResponse,
  requiresHumanApproval,
  type PermissionDecision,
} from "./policy"

const DEFAULT_MODEL = "openai/gpt-5.5-fast"
const DEFAULT_TIMEOUT_MS = 20_000
const MAX_TIMEOUT_MS = 120_000
const MIN_TIMEOUT_MS = 1_000
const MAX_AUDIT_RESOURCE_CHARS = 2_000

interface ModelReference {
  providerID: string
  id: string
  label: string
}

function optionString(options: Record<string, unknown>, key: string): string | undefined {
  const value = options[key]
  return typeof value === "string" && value.trim() ? value.trim() : undefined
}

function evaluatorModel(options: Record<string, unknown>): ModelReference {
  const label = optionString(options, "model") ?? process.env.OPENCODE_EVALUATOR_MODEL?.trim() ?? DEFAULT_MODEL
  const slash = label.indexOf("/")
  const providerID = slash === -1 ? "" : label.slice(0, slash)
  const id = slash === -1 ? "" : label.slice(slash + 1)

  if (!providerID || !id) {
    throw new Error(`Evaluator model must use provider/model format, got ${JSON.stringify(label)}`)
  }

  return { providerID, id, label }
}

function evaluatorTimeout(options: Record<string, unknown>): number {
  const configured = options.timeoutMs ?? process.env.OPENCODE_EVALUATOR_TIMEOUT_MS ?? DEFAULT_TIMEOUT_MS
  const milliseconds = Number(configured)
  if (!Number.isFinite(milliseconds) || milliseconds < MIN_TIMEOUT_MS || milliseconds > MAX_TIMEOUT_MS) {
    return DEFAULT_TIMEOUT_MS
  }
  return milliseconds
}

function auditPath(options: Record<string, unknown>): string | undefined {
  const configured = optionString(options, "auditPath") ?? process.env.OPENCODE_PERMISSION_AUDIT?.trim()
  return configured || undefined
}

function createAuditLogger(path: string | undefined) {
  return async (record: Record<string, unknown>) => {
    if (!path) return
    try {
      await mkdir(dirname(path), { recursive: true })
      await appendFile(path, `${JSON.stringify(record)}\n`, { encoding: "utf8", mode: 0o600 })
    } catch (error) {
      console.error("Guardians of the Diff audit write failed", error)
    }
  }
}

async function withTimeout<T>(promise: Promise<T>, milliseconds: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  const expired = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`evaluator timed out after ${milliseconds}ms`)), milliseconds)
  })

  try {
    return await Promise.race([promise, expired])
  } finally {
    if (timer) clearTimeout(timer)
  }
}

export default Plugin.define({
  id: "guardians-of-the-diff",
  async setup(ctx) {
    const options = ctx.options as Record<string, unknown>
    const audit = createAuditLogger(auditPath(options))

    await audit({
      type: "plugin_started",
      timestamp: new Date().toISOString(),
      plugin: "guardians-of-the-diff",
      opencodeVersion: ctx.app.version,
      location: ctx.location.directory,
      configuredModel: optionString(options, "model") ?? process.env.OPENCODE_EVALUATOR_MODEL ?? DEFAULT_MODEL,
    })

    await ctx.permission.hook("evaluate", async (event) => {
      const started = Date.now()
      const initialEffect = event.effect
      let model = "human-edit-policy"
      let decision: PermissionDecision = humanEditDecision()
      let errorMessage: string | undefined

      if (!requiresHumanApproval(event.action)) {
        try {
          const selectedModel = evaluatorModel(options)
          model = selectedModel.label
          const messages = await ctx.session.context({ sessionID: event.sessionID })
          const recentContext = Array.isArray(messages) ? messages.slice(-8) : messages
          const review = await withTimeout(
            ctx.generate.text({
              model: { providerID: selectedModel.providerID, id: selectedModel.id },
              prompt: buildEvaluationPrompt({
                action: event.action,
                resources: event.resources,
                initialEffect,
                metadata: event.metadata,
                context: recentContext,
              }),
            }),
            evaluatorTimeout(options),
          )
          decision = parseEvaluatorResponse(review.text)
        } catch (error) {
          errorMessage = error instanceof Error ? error.message : String(error)
          decision = {
            effect: "ask",
            reason: "Automatic permission evaluation failed; human confirmation is required.",
          }
          console.error("Guardians of the Diff failed closed to ask", error)
        }
      }

      event.effect = decision.effect
      event.message = decision.reason

      await audit({
        type: "permission_evaluation",
        timestamp: new Date().toISOString(),
        requestID: randomUUID(),
        sessionID: event.sessionID,
        agent: event.agent,
        source: event.source,
        action: event.action,
        resources: event.resources.map((resource) => clip(resource, MAX_AUDIT_RESOURCE_CHARS)),
        initialEffect,
        finalEffect: decision.effect,
        model,
        latencyMs: Date.now() - started,
        reason: decision.reason,
        error: errorMessage,
      })
    })
  },
})
