type TunablePlan = { name: string; vibe: string; changes: string[] };

// Keep every preference in both the image request and the later executable-plan
// goal. Rebuilding from the original plan prevents repeated 定制 suffixes.
export function refinedTunePlan<T extends TunablePlan>(plan: T, preferences: string[]): T {
  const tweaks = preferences.map((value) => value.trim()).filter(Boolean);
  if (!tweaks.length) return plan;
  return {
    ...plan,
    name: plan.name + ' · 定制',
    vibe: plan.vibe + '；用户调整：' + tweaks.join('；'),
    changes: [...plan.changes, ...tweaks.map((value) => '用户调整：' + value)],
  };
}
