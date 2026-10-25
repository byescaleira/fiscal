import { renderSections } from './web-sections.js';

const ROUTES = ['overview', 'items', 'groups'];
const TITLES = { overview: 'navOverview', items: 'navItems', groups: 'navGroups' };

const view = { status: '', group: '', query: '', sort: 'date', descending: true, snapshot: null, kit: null };

function slot(name) {
  return document.querySelector(`[data-slot="${name}"]`);
}

function clamp(value) {
  return Math.min(Math.max(Number(value) || 0, 0), 1);
}

export function currentRoute() {
  const route = location.hash.replace('#', '');
  const groupsVisible = !document.querySelector('[data-nav="groups"]')?.hidden;
  if (route === 'groups' && !groupsVisible) return 'overview';
  return ROUTES.includes(route) ? route : 'overview';
}

export function applyRoute(kit) {
  const route = currentRoute();
  document.querySelectorAll('[data-route-view]').forEach((section) => { section.hidden = section.dataset.routeView !== route; });
  document.querySelectorAll('[data-route]').forEach((link) => {
    if (link.dataset.route === route) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  slot('route-title').textContent = kit.t(TITLES[route]);
}

export function renderDashboard(snapshot, kit) {
  view.snapshot = snapshot;
  view.kit = kit;
  const { locale } = kit;
  const period = snapshot.period ?? {};
  const periodName = period.title ?? (period.start ? kit.day(period.start, { month: 'long', year: 'numeric' }) : '');

  const profile = snapshot.profile ?? {};
  const avatar = slot('avatar');
  avatar.textContent = profile.initials || (profile.name || 'Fiscal').charAt(0).toLocaleUpperCase(locale);
  avatar.style.setProperty('--badge', kit.palette(profile.color));
  slot('profile-name').textContent = profile.name || 'Fiscal';
  slot('side-period').textContent = periodName;
  slot('head-period').textContent = periodName;
  slot('item-count').textContent = new Intl.NumberFormat(locale).format(snapshot.items?.length ?? 0);
  document.querySelector('[data-nav="groups"]').hidden = !(snapshot.groups?.length);

  const status = slot('state');
  status.hidden = !snapshot.status?.label;
  if (snapshot.status?.label) {
    status.textContent = snapshot.status.label;
    status.style.setProperty('--chip', kit.tone(snapshot.status.tone) ?? 'var(--positive)');
  }

  renderMetrics(snapshot, kit);
  renderGroups(snapshot, kit);
  renderUpcoming(snapshot, kit);
  renderSections(snapshot, kit);
  renderRecent(snapshot, kit);
  renderFilters(snapshot, kit);
  renderTable();
  applyRoute(kit);
}

function renderMetrics(snapshot, kit) {
  const metrics = (snapshot.metrics ?? []).slice(0, 4);
  slot('metrics').hidden = !metrics.length;
  slot('metrics').replaceChildren(...metrics.map((metric) => {
    const node = kit.element('div', 'dash-kpi');
    node.append(kit.element('span', 'footnote', metric.title ?? ''));
    const value = kit.element('strong', '', kit.format(metric.value, metric.format));
    const color = kit.tone(metric.tone);
    if (color && metric.tone !== 'positive') value.style.color = color;
    node.append(value);
    if (metric.ratio !== undefined) {
      const meter = kit.bar(color ?? 'var(--tint)', metric.ratio);
      if (metric.elapsed !== undefined) {
        meter.style.setProperty('--elapsed', `${clamp(metric.elapsed) * 100}%`);
        meter.append(kit.element('b'));
      }
      node.append(meter);
    }
    if (metric.detail) node.append(kit.element('span', 'footnote', metric.detail));
    return node;
  }));
}

function groupRow(group, kit, percent) {
  const ratio = group.target > 0 ? group.value / group.target : clamp(group.share);
  const row = kit.element('div', 'dash-budget');
  const name = kit.element('div', 'dash-budget-name');
  name.append(kit.badge(group.name, group.color), kit.element('span', '', group.name));
  const figures = group.target > 0
    ? kit.t('groupOf', { value: kit.format(group.value, group.format), target: kit.format(group.target, group.format) })
    : kit.format(group.value, group.format);
  const share = kit.element('span', 'dash-budget-share', percent.format(ratio));
  const color = kit.tone(group.tone) ?? kit.palette(group.color);
  row.append(name, kit.bar(color, ratio), kit.element('span', 'dash-budget-figures', figures), share);
  return row;
}

function renderGroups(snapshot, kit) {
  const groups = snapshot.groups ?? [];
  const percent = new Intl.NumberFormat(kit.locale, { style: 'percent' });
  const top = document.querySelector('[data-block="groups-top"]');
  top.hidden = !groups.length;
  slot('groups-top').replaceChildren(...groups.slice(0, 5).map((group) => groupRow(group, kit, percent)));
  slot('groups').replaceChildren(...(groups.length
    ? groups.map((group) => groupRow(group, kit, percent))
    : [kit.element('p', 'web-empty', kit.t('noItems'))]));
  const total = groups.reduce((sum, group) => sum + Math.max(Number(group.value) || 0, 0), 0);
  slot('group-share').hidden = !(total > 0);
  slot('group-share').replaceChildren(...groups.map((group) => {
    const part = kit.element('i');
    const share = total > 0 ? Math.max(Number(group.value) || 0, 0) / total : 0;
    part.style.flexGrow = String(Math.max(share, 0.001));
    part.style.background = kit.palette(group.color);
    part.title = `${group.name} · ${percent.format(share)}`;
    return part;
  }));
}

function renderUpcoming(snapshot, kit) {
  const items = snapshot.upcoming ?? [];
  document.querySelector('[data-block="upcoming"]').hidden = !items.length;
  slot('upcoming').replaceChildren(...items.map((item) => {
    const row = kit.element('div', 'dash-line');
    const body = kit.element('div');
    const detail = [item.date ? kit.day(item.date, { day: 'numeric', month: 'short' }) : '', item.detail].filter(Boolean).join(' · ');
    body.append(kit.element('div', 'web-item-title', item.title), kit.element('div', 'footnote', detail));
    row.append(kit.badge(item.title, item.color ?? 'denim'), body, kit.element('span', 'web-item-amount', kit.format(item.value, item.format)));
    return row;
  }));
}

function sorted(items) {
  return [...items].sort((a, b) => {
    const order = view.sort === 'value'
      ? (Number(a.value) || 0) - (Number(b.value) || 0)
      : String(a.date ?? '').localeCompare(String(b.date ?? ''));
    return view.descending ? -order : order;
  });
}

function statusChip(item, kit) {
  if (!item.status?.label) return null;
  const chip = kit.element('span', 'chip', item.status.label);
  chip.style.setProperty('--chip', kit.tone(item.status.tone) ?? 'var(--secondary)');
  return chip;
}

function renderRecent(snapshot, kit) {
  const recent = [...(snapshot.items ?? [])].sort((a, b) => String(b.date ?? '').localeCompare(String(a.date ?? ''))).slice(0, 8);
  slot('recent').replaceChildren(...(recent.length ? recent.map((item) => {
    const row = kit.element('div', 'dash-line');
    const body = kit.element('div');
    const detail = [item.date ? kit.day(item.date, { day: 'numeric', month: 'short' }) : '', item.group?.name].filter(Boolean).join(' · ');
    body.append(kit.element('div', 'web-item-title', item.title), kit.element('div', 'footnote', detail));
    if (item.status?.tone === 'neutral') row.classList.add('canceled');
    row.append(kit.badge(item.group?.name || item.title, item.group?.color), body, kit.element('span', 'web-item-amount', kit.format(item.value, item.format)));
    return row;
  }) : [kit.element('p', 'web-empty', kit.t('noItems'))]));
}

function renderFilters(snapshot, kit) {
  const items = snapshot.items ?? [];
  const labels = [...new Set(items.map((item) => item.status?.label).filter(Boolean))];
  if (!labels.includes(view.status)) view.status = '';
  const segment = slot('status-filter');
  segment.hidden = labels.length < 2;
  segment.replaceChildren(...['', ...labels].map((label) => {
    const button = kit.element('button', '', label || kit.t('filterAll'));
    button.type = 'button';
    button.dataset.status = label;
    button.setAttribute('aria-pressed', String(label === view.status));
    return button;
  }));

  const select = slot('group-filter');
  const names = [...new Set(items.map((item) => item.group?.name).filter(Boolean))].sort((a, b) => a.localeCompare(b, kit.locale));
  const options = [kit.element('option', '', kit.t('allGroups'))];
  options[0].value = '';
  for (const name of names) {
    const option = kit.element('option', '', name);
    option.value = name;
    options.push(option);
  }
  select.replaceChildren(...options);
  select.hidden = names.length < 2;
  select.value = names.includes(view.group) ? view.group : '';
  view.group = select.value;
}

function matches(item) {
  if (view.status && item.status?.label !== view.status) return false;
  if (view.group && item.group?.name !== view.group) return false;
  if (!view.query) return true;
  const haystack = [item.title, item.group?.name, ...(item.tags ?? [])].join(' ').toLocaleLowerCase(view.kit.locale);
  return haystack.includes(view.query.toLocaleLowerCase(view.kit.locale));
}

export function renderTable() {
  const { snapshot, kit } = view;
  if (!snapshot || !kit) return;
  const { element, day, t, locale } = kit;
  const rows = sorted((snapshot.items ?? []).filter(matches));
  slot('item-body').replaceChildren(...rows.map((item) => {
    const row = element('tr');
    if (item.status?.tone === 'neutral') row.classList.add('canceled');
    const date = element('td', 'dash-date', item.date ? day(item.date, { day: '2-digit', month: 'short' }) : '');
    date.dataset.label = t('colDate');
    const title = element('td', 'dash-description');
    title.append(element('div', 'web-item-title', item.title));
    if (item.tags?.length) {
      const tags = element('div', 'dash-tags');
      for (const tag of item.tags) {
        const chip = element('span', 'chip', tag);
        chip.style.setProperty('--chip', 'var(--denim)');
        tags.append(chip);
      }
      title.append(tags);
    }
    const group = element('td', 'dash-category');
    group.dataset.label = t('colGroup');
    if (item.group?.name) {
      const dot = element('i', 'dash-dot');
      dot.style.background = kit.palette(item.group.color);
      group.append(dot, document.createTextNode(item.group.name));
    }
    const status = element('td', 'dash-status');
    status.dataset.label = t('colStatus');
    const chip = statusChip(item, kit);
    if (chip) status.append(chip);
    const value = element('td', 'num web-item-amount', kit.format(item.value, item.format));
    row.append(date, title, group, status, value);
    return row;
  }));
  slot('item-empty').hidden = rows.length > 0;
  slot('item-summary').textContent = t('itemSummary', { count: new Intl.NumberFormat(locale).format(rows.length) });
  document.querySelectorAll('[data-sort]').forEach((button) => {
    const active = button.dataset.sort === view.sort;
    const order = active ? (view.descending ? 'descending' : 'ascending') : 'none';
    button.setAttribute('aria-sort', order);
    button.closest('th').setAttribute('aria-sort', order);
  });
}

const PACK_ROW = 2;
const packer = typeof ResizeObserver === 'function' ? new ResizeObserver(() => requestAnimationFrame(pack)) : null;

function gridItems(grid) {
  return [...grid.children].flatMap((child) => {
    if (getComputedStyle(child).display === 'contents') return [...child.children];
    for (const panel of child.classList.contains('dash-stack') ? child.children : []) panel.style.gridRowEnd = '';
    return [child];
  });
}

function pack() {
  document.querySelectorAll('.dash-grid').forEach((grid) => {
    const gap = parseFloat(getComputedStyle(grid).columnGap) || 0;
    for (const item of gridItems(grid)) {
      const height = item.getBoundingClientRect().height;
      if (height > 0) item.style.gridRowEnd = `span ${Math.ceil((height + gap) / PACK_ROW)}`;
    }
  });
}

function bindPacking() {
  if (!packer) return;
  document.querySelectorAll('.dash-grid').forEach((grid) => {
    grid.classList.add('packed');
    grid.querySelectorAll('.dash-panel, .dash-stack').forEach((item) => packer.observe(item));
  });
}

export function bindDashboard(kit) {
  bindPacking();
  window.addEventListener('hashchange', () => applyRoute(view.kit ?? kit));
  slot('search').addEventListener('input', (event) => {
    view.query = event.target.value.trim();
    renderTable();
  });
  slot('group-filter').addEventListener('change', (event) => {
    view.group = event.target.value;
    renderTable();
  });
  slot('status-filter').addEventListener('click', (event) => {
    const button = event.target.closest('[data-status]');
    if (!button) return;
    view.status = button.dataset.status;
    slot('status-filter').querySelectorAll('[data-status]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
    renderTable();
  });
  document.querySelectorAll('[data-sort]').forEach((button) => button.addEventListener('click', () => {
    if (view.sort === button.dataset.sort) view.descending = !view.descending;
    else {
      view.sort = button.dataset.sort;
      view.descending = true;
    }
    renderTable();
  }));
}
