export const FLAGS = [
  { name: 'guides', title: 'Guias', description: 'Os guias que explicam cada tela do app.', defaultValue: true },
  { name: 'partyIcons', title: 'Ícones de partido', description: 'Os ícones alternativos com as cores de cada partido, em Ajustes › Aparência › Ícone do app.', defaultValue: false },
  { name: 'liveResults', title: 'Apuração ao vivo', description: 'A apuração das eleições em tempo real, com a Atividade ao Vivo e o widget.', defaultValue: true },
  { name: 'highlightAlerts', title: 'Alertas do destaque', description: 'A notificação do destaque do momento, a mesma para todo mundo.', defaultValue: true },
  { name: 'intelligence', title: 'Explicações no aparelho', description: 'As explicações em português simples escritas pela Apple Intelligence no próprio aparelho, só a partir dos fatos oficiais.', defaultValue: true },
];

export const FLAG_NAMES = FLAGS.map((flag) => flag.name);

export function parseFlagForm(form) {
  const name = form.get('name') ?? '';
  if (!FLAG_NAMES.includes(name)) return { error: 'unknown_flag' };
  const rollout = Number(form.get('rollout') ?? 100);
  if (!Number.isInteger(rollout) || rollout < 0 || rollout > 100) return { error: 'invalid_rollout' };
  return { value: { name, isOn: form.get('isOn') === 'on', rollout } };
}
