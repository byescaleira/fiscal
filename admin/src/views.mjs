const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export const h = (value) => String(value ?? '').replace(/[&<>"']/g, (character) => ENTITIES[character]);

const ZONE = 'America/Sao_Paulo';
const time = (iso) => new Date(iso).toLocaleTimeString('pt-BR', { timeZone: ZONE, hour: '2-digit', minute: '2-digit' });
const dateTime = (iso) =>
  new Date(iso).toLocaleString('pt-BR', { timeZone: ZONE, day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
const number = (value) => Number(value ?? 0).toLocaleString('pt-BR');

function bytes(value) {
  if (value >= 1024 * 1024) return `${(value / 1024 / 1024).toLocaleString('pt-BR', { maximumFractionDigits: 1 })} MB`;
  if (value >= 1024) return `${Math.round(value / 1024).toLocaleString('pt-BR')} KB`;
  return `${value} B`;
}

function duration(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days) return `${days} d ${hours} h`;
  if (hours) return `${hours} h ${minutes} min`;
  return `${minutes} min`;
}

const TABS = [
  ['overview', 'Visão geral', '/admin/overview'],
  ['flags', 'Flags', '/admin/flags'],
  ['versions', 'Versões', '/admin/versions'],
  ['bridge', 'Ponte', '/admin/bridge'],
  ['audit', 'Registro', '/admin/audit'],
];

export function layout({ title, body, active = null, signedIn = false }) {
  const tabs = signedIn
    ? `<nav class="admin-tabs" aria-label="Seções">${TABS.map(([key, label, href]) => `<a href="${href}"${key === active ? ' aria-current="page"' : ''}>${label}</a>`).join('')}</nav>`
    : '';
  const logout = signedIn
    ? '<form method="post" action="/admin/logout"><button class="button quiet small-quiet" type="submit">Sair</button></form>'
    : '';
  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<title>${h(title)} · Fiscal Admin</title>
<link rel="icon" href="/assets/favicon.png">
<link rel="stylesheet" href="/style.css">
<link rel="stylesheet" href="/admin/assets/admin.css">
<script src="/admin/assets/admin.js" defer></script>
</head>
<body>
<header class="nav">
<div class="page">
<a class="brand" href="/admin"><img class="icon-light" src="/assets/icon.png" alt=""><img class="icon-dark" src="/assets/icon-dark.png" alt="">Admin</a>
${logout}
</div>
</header>
<main class="page admin">
${tabs}
${body}
</main>
</body>
</html>`;
}

const notice = (message, kind = 'error') => (message ? `<p class="notice ${kind}" role="${kind === 'error' ? 'alert' : 'status'}">${h(message)}</p>` : '');

export function setupPage({ available }) {
  if (!available) {
    return layout({
      title: 'Configuração',
      body: `<section class="admin-card"><h1>Código expirado</h1><p class="subheadline">O código de configuração vale 30 minutos. Reinicie o serviço na VPS para gerar outro e leia o novo código no log.</p></section>`,
    });
  }
  return layout({
    title: 'Configuração',
    body: `<section class="admin-card">
<h1>Primeiro acesso</h1>
<p class="subheadline">Digite o código de configuração do log, crie a senha e registre uma passkey. Depois disso esta página deixa de existir.</p>
<form class="stack" data-webauthn="setup">
<label>Código de configuração<input name="code" autocomplete="one-time-code" autocapitalize="characters" spellcheck="false" required></label>
<label>Senha (mínimo 14 caracteres)<input name="password" type="password" minlength="14" autocomplete="new-password" required></label>
<label>Repita a senha<input name="confirm" type="password" minlength="14" autocomplete="new-password" required></label>
<p class="notice error" data-error hidden></p>
<button class="button" type="submit">Criar senha e registrar passkey</button>
</form>
</section>`,
  });
}

export function loginPage({ message } = {}) {
  return layout({
    title: 'Entrar',
    body: `<section class="admin-card">
<h1>Entrar</h1>
<p class="subheadline">Senha e passkey, sempre.</p>
${notice(message)}
<form class="stack" data-webauthn="login">
<input name="username" autocomplete="username webauthn" value="admin" hidden>
<label>Senha<input name="password" type="password" autocomplete="current-password" required></label>
<p class="notice error" data-error hidden></p>
<button class="button" type="submit">Entrar com passkey</button>
</form>
</section>`,
  });
}

function chart({ title, minutes, series, unit }) {
  const width = 600;
  const height = 150;
  const max = Math.max(1, ...minutes.flatMap((minute) => series.map((item) => minute[item.key])));
  const step = width / (minutes.length - 1);
  const y = (value) => height - 4 - (value / max) * (height - 12);
  const lines = series
    .map((item) => {
      const points = minutes.map((minute, index) => `${(index * step).toFixed(1)},${y(minute[item.key]).toFixed(1)}`).join(' ');
      return `<polyline points="${points}" fill="none" stroke="var(--${item.color})" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>`;
    })
    .join('');
  const grid = [0.5, 1].map((ratio) => `<line x1="0" x2="${width}" y1="${y(max * ratio).toFixed(1)}" y2="${y(max * ratio).toFixed(1)}" class="chart-grid" vector-effect="non-scaling-stroke"/>`).join('');
  const hits = minutes
    .map((minute, index) => {
      const label = `${time(minute.minute)}: ${series.map((item) => `${item.label.toLowerCase()} ${number(minute[item.key])}`).join(', ')}`;
      return `<rect x="${Math.max(0, index * step - step / 2).toFixed(1)}" y="0" width="${step.toFixed(1)}" height="${height}" class="chart-hit"><title>${h(label)}</title></rect>`;
    })
    .join('');
  const last = minutes.at(-2) ?? minutes.at(-1);
  const legend = series
    .map((item) => `<li style="--swatch: var(--${item.color})"><i></i>${h(item.label)} <strong>${number(last[item.key])}</strong><span class="footnote">no último minuto</span></li>`)
    .join('');
  const rows = minutes
    .slice()
    .reverse()
    .map((minute) => `<tr><td>${time(minute.minute)}</td>${series.map((item) => `<td>${number(minute[item.key])}</td>`).join('')}</tr>`)
    .join('');
  return `<figure class="chart">
<figcaption><strong>${h(title)}</strong><span class="footnote">máximo ${number(max)} ${h(unit)}</span></figcaption>
<ul class="chart-legend">${legend}</ul>
<svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" role="img" aria-label="${h(title)} na última hora">${grid}${lines}${hits}</svg>
<div class="chart-axis footnote"><span>${time(minutes[0].minute)}</span><span>agora</span></div>
<details><summary class="footnote">Ver tabela</summary><table><thead><tr><th>Minuto</th>${series.map((item) => `<th>${h(item.label)}</th>`).join('')}</tr></thead><tbody>${rows}</tbody></table></details>
</figure>`;
}

export function overviewPage({ stats, error }) {
  if (error) {
    return layout({ title: 'Visão geral', active: 'overview', signedIn: true, body: `<h1>Visão geral</h1>${notice(`A ponte não respondeu (${error}).`)}` });
  }
  const { config, snapshots, memory, totals, uptimeSeconds } = stats;
  const minutes = stats.minutes.map((minute) => ({ ...minute, changes: minute.writes + minute.deletes }));
  const occupancy = config.maxSnapshots ? Math.min(1, snapshots.count / config.maxSnapshots) : 1;
  const last = minutes.at(-2) ?? minutes.at(-1);
  const state = config.enabled ? '<span class="chip capsule" style="--chip: var(--positive)">Ativa</span>' : '<span class="chip capsule" style="--chip: var(--warning)">Pausada</span>';
  const body = `<h1>Visão geral</h1>
<div class="group">
<div class="row split"><span>Ponte</span>${state}</div>
<div class="row"><div class="split"><span>Sessões guardadas</span><strong>${number(snapshots.count)} de ${number(config.maxSnapshots)}</strong></div>
<div class="bar filled" style="--value: ${(occupancy * 100).toFixed(1)}%; --bar: var(${occupancy > 0.8 ? '--negative' : '--tint'})"><i></i></div>
<p class="footnote">Cerca de ${bytes(snapshots.bytes)} em pacotes cifrados</p></div>
<div class="row split"><span>Memória</span><strong>${bytes(memory.rss)}</strong></div>
<div class="row split"><span>No ar há</span><strong>${duration(uptimeSeconds)}</strong></div>
</div>
<h2>Último minuto</h2>
<div class="tiles">
<div class="tile"><span class="footnote">Leituras/min</span><strong>${number(last.reads)}</strong></div>
<div class="tile"><span class="footnote">Escritas/min</span><strong>${number(last.changes)}</strong></div>
<div class="tile"><span class="footnote">429/min</span><strong>${number(last.rateLimited)}</strong></div>
<div class="tile"><span class="footnote">503/min</span><strong>${number(last.unavailable)}</strong></div>
</div>
<h2>Última hora</h2>
<div class="group charts">
${chart({ title: 'Requisições por minuto', unit: 'por minuto', minutes, series: [{ key: 'reads', label: 'Leituras', color: 'denim' }, { key: 'changes', label: 'Escritas', color: 'orange' }] })}
${chart({ title: 'Recusas por minuto', unit: 'por minuto', minutes, series: [{ key: 'rateLimited', label: '429', color: 'rust' }, { key: 'unavailable', label: '503', color: 'mustard' }] })}
</div>
<p class="footnote">Na hora: ${number(totals.reads)} leituras, ${number(totals.writes)} escritas, ${number(totals.deletes)} exclusões, ${number(totals.notFound)} respostas 404, ${number(totals.rateLimited)} respostas 429 e ${number(totals.unavailable)} respostas 503. <a href="/admin/overview">Atualizar</a></p>`;
  return layout({ title: 'Visão geral', active: 'overview', signedIn: true, body });
}

const ENV_LABEL = { development: 'Desenvolvimento', production: 'Produção' };

export function flagsPage({ environment, flags, remote, error, readAt, message, configured }) {
  const tabs = Object.entries(ENV_LABEL)
    .map(([key, label]) => `<a href="/admin/flags?env=${key}"${key === environment ? ' aria-current="page"' : ''}>${label}</a>`)
    .join('');
  const rows = flags
    .map((flag) => {
      const value = remote?.get(flag.name);
      const isOn = value ? value.isOn : flag.defaultValue;
      const rollout = value ? value.rollout : 100;
      const remoteChip = value
        ? `<span class="chip" style="--chip: var(${value.isOn ? '--positive' : '--secondary'})">Remoto: ${value.isOn ? `ligado em ${value.rollout}%` : 'desligado'}</span>`
        : '<span class="chip" style="--chip: var(--secondary)">Sem valor remoto</span>';
      return `<form class="row flag" method="post" action="/admin/flags"${environment === 'production' ? ' data-confirm="Gravar esta flag em Produção?"' : ''}>
<input type="hidden" name="env" value="${environment}">
<input type="hidden" name="name" value="${h(flag.name)}">
<div class="flag-head"><div><strong>${h(flag.title)}</strong><div class="footnote"><code>${h(flag.name)}</code> · padrão do app: ${flag.defaultValue ? 'ligado' : 'desligado'}</div></div>
<label class="switch"><input type="checkbox" name="isOn" role="switch"${isOn ? ' checked' : ''}${remote ? '' : ' disabled'}><span aria-hidden="true"></span><span class="visually-hidden">Ligado</span></label></div>
<div class="flag-rollout"><label for="rollout-${h(flag.name)}" class="footnote">Rollout</label><input id="rollout-${h(flag.name)}" type="range" name="rollout" min="0" max="100" step="1" value="${rollout}"${remote ? '' : ' disabled'}><output for="rollout-${h(flag.name)}">${rollout}%</output></div>
<div class="flag-actions">${remoteChip}<span class="spacer"></span>${value ? `<button class="button quiet small-quiet" type="submit" name="action" value="reset"${remote ? '' : ' disabled'}>Usar padrão</button>` : ''}<button class="button small-solid" type="submit" name="action" value="save"${remote ? '' : ' disabled'}>Salvar</button></div>
</form>`;
    })
    .join('');
  const status = !configured
    ? notice('A chave server-to-server do CloudKit ainda não foi configurada (CLOUDKIT_KEY_ID). Os valores abaixo são os padrões do app.')
    : error
      ? notice(`Não foi possível ler o CloudKit (${error}). Nada pode ser gravado até a leitura funcionar.`)
      : '';
  const body = `<h1>Flags</h1>
<nav class="segmented" aria-label="Ambiente">${tabs}</nav>
${notice(message?.text, message?.kind)}
${status}
<div class="group">${rows}</div>
<p class="footnote">${readAt ? `Lido do CloudKit às ${dateTime(readAt)}. ` : ''}O app só pega o novo valor na próxima abertura. Sem valor remoto, vale o padrão do app.${environment === 'production' ? ' Em Produção, o tipo FeatureFlag só existe depois do Deploy Schema Changes no CloudKit Console.' : ''}</p>`;
  return layout({ title: 'Flags', active: 'flags', signedIn: true, body });
}

const releaseLine = (release) => `mínima ${release.minimumVersion} (${release.minimumBuild}), recomendada ${release.recommendedVersion} (${release.recommendedBuild})`;

export function versionsPage({ environment, platforms, remote, error, readAt, message, configured }) {
  const tabs = Object.entries(ENV_LABEL)
    .map(([key, label]) => `<a href="/admin/versions?env=${key}"${key === environment ? ' aria-current="page"' : ''}>${label}</a>`)
    .join('');
  const disabled = remote ? '' : ' disabled';
  const field = (platform, name, label, value, kind) =>
    `<label class="row field"><span>${label}<span class="footnote">${kind === 'version' ? 'Formato x.y.z, como 1.2.0.' : 'Número inteiro da build.'}</span></span><input name="${name}" id="${h(platform)}-${name}" ${kind === 'version' ? 'inputmode="decimal" pattern="\\d+\\.\\d+\\.\\d+" placeholder="1.0.0"' : 'type="number" inputmode="numeric" min="0" step="1" placeholder="1"'} value="${h(value ?? '')}" required${disabled}></label>`;
  const sections = platforms
    .map((platform) => {
      const value = remote?.get(platform.name);
      const chip = value
        ? `<span class="chip" style="--chip: var(--positive)">Remoto: ${h(releaseLine(value))}</span>`
        : '<span class="chip" style="--chip: var(--secondary)">Sem política: o app nunca pede atualização</span>';
      return `<h2>${h(platform.title)} <code>${h(platform.name)}</code></h2>
<form class="group" method="post" action="/admin/versions"${environment === 'production' ? ` data-confirm="Gravar as versões de ${h(platform.title)} em Produção?"` : ''}>
<input type="hidden" name="env" value="${environment}">
<input type="hidden" name="platform" value="${h(platform.name)}">
${field(platform.name, 'minimumVersion', 'Versão mínima', value?.minimumVersion, 'version')}
${field(platform.name, 'minimumBuild', 'Build mínima', value?.minimumBuild, 'build')}
${field(platform.name, 'recommendedVersion', 'Versão recomendada', value?.recommendedVersion, 'version')}
${field(platform.name, 'recommendedBuild', 'Build recomendada', value?.recommendedBuild, 'build')}
<div class="row flag-actions">${chip}<span class="spacer"></span>${value ? `<button class="button quiet small-quiet" type="submit" name="action" value="reset" formnovalidate${disabled}>Remover política</button>` : ''}<button class="button small-solid" type="submit" name="action" value="save"${disabled}>Salvar</button></div>
</form>`;
    })
    .join('');
  const status = !configured
    ? notice('A chave server-to-server do CloudKit ainda não foi configurada (CLOUDKIT_KEY_ID). Nada pode ser lido nem gravado.')
    : error
      ? notice(`Não foi possível ler o CloudKit (${error}). Nada pode ser gravado até a leitura funcionar.`)
      : '';
  const body = `<h1>Versões</h1>
<nav class="segmented" aria-label="Ambiente">${tabs}</nav>
${notice(message?.text, message?.kind)}
${status}
<p class="footnote">Abaixo da versão mínima <strong>ou</strong> da build mínima, o app bloqueia e só deixa atualizar e exportar os dados. Abaixo só da recomendada, mostra um aviso que a pessoa pode dispensar (uma vez por versão recomendada). A recomendada nunca fica abaixo da mínima.</p>
${sections}
<p class="footnote">${readAt ? `Lido do CloudKit às ${dateTime(readAt)}. ` : ''}O app lê a política ao abrir e ao voltar para o primeiro plano (no máximo a cada 15 minutos; a cada minuto quando está bloqueado) e guarda a última no aparelho.${environment === 'production' ? ' Em Produção, o tipo AppRelease só existe depois do Deploy Schema Changes no CloudKit Console.' : ''}</p>`;
  return layout({ title: 'Versões', active: 'versions', signedIn: true, body });
}

export function bridgePage({ config, error, message }) {
  if (!config) {
    return layout({ title: 'Ponte', active: 'bridge', signedIn: true, body: `<h1>Ponte</h1>${notice(`A ponte não respondeu (${error}).`)}` });
  }
  const field = (name, label, value, min, max, hint) =>
    `<label class="row field"><span>${label}<span class="footnote">${hint}</span></span><input name="${name}" type="number" inputmode="numeric" min="${min}" max="${max}" step="1" value="${value}" required></label>`;
  const body = `<h1>Ponte</h1>
${notice(message?.text, message?.kind)}
<form class="group" method="post" action="/admin/bridge" data-confirm="${config.enabled ? 'Pausar a ponte? O Fiscal na Web para de receber e entregar resumos.' : 'Retomar a ponte?'}">
<input type="hidden" name="enabledField" value="1">
${config.enabled ? '' : '<input type="hidden" name="enabled" value="on">'}
<div class="row split"><span>${config.enabled ? 'A ponte está <strong>ativa</strong>.' : 'A ponte está <strong>pausada</strong>: leituras e escritas respondem 503.'}</span>
<button class="button ${config.enabled ? 'quiet small-quiet' : 'small-solid'}" type="submit">${config.enabled ? 'Pausar' : 'Retomar'}</button></div>
</form>
<h2>Limites</h2>
<form class="group" method="post" action="/admin/bridge">
${field('maxSnapshots', 'Sessões guardadas', config.maxSnapshots, 0, 100000, 'Acima disso, novas sessões recebem 503.')}
${field('readPerMinute', 'Leituras por minuto por IP', config.readPerMinute, 1, 100000, 'A página busca a cada 2 s esperando o QR.')}
${field('writePerMinute', 'Escritas por minuto por IP', config.writePerMinute, 1, 100000, 'Envios e exclusões do app.')}
${field('maxBody', 'Tamanho máximo do pacote (KB)', Math.round(config.maxBody / 1024), 1, 4096, 'Pacote médio: 20 a 80 KB.')}
${field('ttlHours', 'Validade (horas)', Math.round(config.ttlHours), 1, 24, 'Até 24 h; vale também para as sessões guardadas.')}
<div class="row end"><button class="button small-solid" type="submit">Salvar limites</button></div>
</form>
<p class="footnote">As mudanças valem na hora, sem reiniciar, e ficam salvas na ponte.</p>`;
  return layout({ title: 'Ponte', active: 'bridge', signedIn: true, body });
}

const ACTIONS = {
  setup: () => 'Primeiro acesso: senha e passkey criadas',
  login: () => 'Entrou',
  login_failed: (entry) => `Falha ao entrar (${entry.reason ?? 'credenciais'})`,
  lockout: () => 'IP bloqueado por 15 minutos',
  logout: () => 'Saiu',
  flag_save: (entry) => `Flag ${entry.flag} em ${ENV_LABEL[entry.environment] ?? entry.environment}: ${entry.isOn ? `ligada em ${entry.rollout}%` : 'desligada'}${entry.before ? ` (antes: ${entry.before.isOn ? `ligada em ${entry.before.rollout}%` : 'desligada'})` : ' (antes: sem valor remoto)'}`,
  flag_reset: (entry) => `Flag ${entry.flag} em ${ENV_LABEL[entry.environment] ?? entry.environment}: voltou ao padrão do app`,
  release_save: (entry) =>
    `Versões de ${entry.platform} em ${ENV_LABEL[entry.environment] ?? entry.environment}: ${releaseLine(entry)}${entry.before ? ` (antes: ${releaseLine(entry.before)})` : ' (antes: sem política)'}`,
  release_reset: (entry) => `Versões de ${entry.platform} em ${ENV_LABEL[entry.environment] ?? entry.environment}: política removida${entry.before ? ` (antes: ${releaseLine(entry.before)})` : ''}`,
  bridge_config: (entry) => `Ponte: ${Object.entries(entry.changes ?? {}).map(([key, [from, to]]) => `${key} ${from} → ${to}`).join(', ')}`,
};

export function auditPage({ entries }) {
  const rows = entries.length
    ? entries.map((entry) => `<div class="row"><div>${h((ACTIONS[entry.action] ?? (() => entry.action))(entry))}</div><div class="footnote">${dateTime(entry.at)} · ${h(entry.ip)}</div></div>`).join('')
    : '<div class="row footnote">Nada registrado ainda.</div>';
  return layout({ title: 'Registro', active: 'audit', signedIn: true, body: `<h1>Registro</h1><div class="group">${rows}</div><p class="footnote">Só ações do admin, as 200 mais recentes.</p>` });
}

export function notFoundPage() {
  return layout({ title: 'Não encontrado', body: '<section class="admin-card"><h1>Não encontrado</h1><p><a href="/admin">Voltar</a></p></section>' });
}
