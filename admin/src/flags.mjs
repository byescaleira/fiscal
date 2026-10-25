export const FLAGS = [
  { name: 'guides', title: 'Guias', defaultValue: true },
];

export const FLAG_NAMES = FLAGS.map((flag) => flag.name);

export function parseFlagForm(form) {
  const name = form.get('name') ?? '';
  if (!FLAG_NAMES.includes(name)) return { error: 'unknown_flag' };
  const rollout = Number(form.get('rollout') ?? 100);
  if (!Number.isInteger(rollout) || rollout < 0 || rollout > 100) return { error: 'invalid_rollout' };
  return { value: { name, isOn: form.get('isOn') === 'on', rollout } };
}
