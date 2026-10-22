export type DisorderRegion = { x: number; y: number; width: number; height: number; label: string };
export type DisorderAssessment = {
  score: number;
  level: "tidy" | "light" | "moderate" | "heavy";
  evidence: string[];
  clutterRegions: DisorderRegion[];
  estimatedMinutes: number;
  sourceSpaceID: string;
};

/** Reject incomplete provider output instead of inventing a fallback score or location. */
export function validatedDisorderAssessment(value: unknown, expectedSpaceID: string): DisorderAssessment {
  const failure = () => { throw new Error("照片评估返回了不完整的数据，请重试或跳过。"); };
  if (!value || typeof value !== "object") return failure();
  const assessment = value as DisorderAssessment;
  if (assessment.sourceSpaceID !== expectedSpaceID) throw new Error("评估照片不属于当前空间，请重新评估。");
  if (!Number.isFinite(assessment.score) || assessment.score < 0 || assessment.score > 100
    || !["tidy", "light", "moderate", "heavy"].includes(assessment.level)
    || !Number.isFinite(assessment.estimatedMinutes) || assessment.estimatedMinutes < 0
    || !Array.isArray(assessment.evidence) || assessment.evidence.length === 0
    || !assessment.evidence.every(detail => typeof detail === "string" && detail.trim().length > 0)
    || !Array.isArray(assessment.clutterRegions)) return failure();
  for (const region of assessment.clutterRegions) {
    if (!region || ![region.x, region.y, region.width, region.height].every(Number.isFinite)
      || region.x < 0 || region.y < 0 || region.width <= 0 || region.height <= 0
      || region.x + region.width > 1 || region.y + region.height > 1
      || typeof region.label !== "string" || !region.label.trim()) return failure();
  }
  return assessment;
}
