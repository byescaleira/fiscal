const SVG = 'http://www.w3.org/2000/svg';

function svg(tag, attributes = {}) {
  const node = document.createElementNS(SVG, tag);
  for (const [name, value] of Object.entries(attributes)) node.setAttribute(name, value);
  return node;
}

function block(name, visible) {
  const node = document.querySelector(`[data-block="${name}"]`);
  if (node) node.hidden = !visible;
  return visible;
}

function slot(name) {
  return document.querySelector(`[data-slot="${name}"]`);
}

function parseDay(value) {
  const [year, month, date] = value.split('-').map(Number);
  return new Date(year, month - 1, date);
}

function key(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

export function renderSections(snapshot, kit) {
  renderHighlights(snapshot, kit);
  renderDaily(snapshot, kit);
  renderHistory(snapshot, kit);
}

function card(kit, highlight) {
  const node = kit.element('div', 'stat web-card');
  node.append(kit.element('span', 'footnote', highlight.title ?? ''));
  const strong = kit.element('strong', '', kit.format(highlight.value, highlight.format));
  const color = kit.tone(highlight.tone);
  if (color) strong.style.color = color;
  node.append(strong);
  if (highlight.detail) node.append(kit.element('span', 'footnote', highlight.detail));
  if (highlight.ratio !== undefined) node.append(kit.bar(color ?? 'var(--tint)', highlight.ratio));
  return node;
}

function renderHighlights(snapshot, kit) {
  const highlights = snapshot.highlights ?? [];
  if (!block('glance', highlights.length > 0)) return;
  slot('highlights').replaceChildren(...highlights.map((highlight) => card(kit, highlight)));
}

function legendItem(kit, color, text, line) {
  const item = kit.element('span', 'footnote');
  const mark = kit.element('i', line ? 'web-legend-line' : 'web-legend-dot');
  mark.style.background = color;
  item.append(mark, document.createTextNode(text));
  return item;
}

function renderDaily(snapshot, kit) {
  const daily = snapshot.daily ?? {};
  const points = daily.points ?? [];
  const period = snapshot.period ?? {};
  if (!block('daily', points.length > 0 && Boolean(period.start && period.end))) return;
  const start = parseDay(period.start);
  const end = parseDay(period.end);
  const days = Math.round((end - start) / 86400000) + 1;
  const goal = Number(daily.goal) || 0;
  const byDay = new Map(points.map((point) => [point.date, Number(point.value) || 0]));
  const values = [...Array(days)].map((_, index) => {
    const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index);
    return { key: key(date), value: byDay.get(key(date)) };
  });
  const max = Math.max(goal * 1.6, ...values.map((item) => item.value ?? 0), 1);
  const width = 640;
  const height = 140;
  const gap = 2;
  const barWidth = width / days - gap;
  const chart = svg('svg', { viewBox: `0 0 ${width} ${height}`, role: 'img', 'aria-label': kit.t('dailyTitle'), class: 'web-svg' });
  values.forEach((item, index) => {
    if (item.value === undefined) {
      chart.append(svg('rect', { x: index * (barWidth + gap), y: height - 2, width: barWidth, height: 2, rx: 1, class: 'web-future' }));
      return;
    }
    const barHeight = Math.max((item.value / max) * height, item.value > 0 ? 3 : 1);
    const rect = svg('rect', { x: index * (barWidth + gap), y: height - barHeight, width: barWidth, height: barHeight, rx: Math.min(barWidth / 2, 4) });
    rect.style.fill = 'var(--tint)';
    const title = svg('title');
    title.textContent = `${kit.day(item.key, { day: 'numeric', month: 'short' })}: ${kit.format(item.value, daily.format)}`;
    rect.append(title);
    chart.append(rect);
  });
  const legend = kit.element('div', 'web-legend');
  if (goal > 0) {
    const goalY = height - (goal / max) * height;
    chart.append(svg('line', { x1: 0, x2: width, y1: goalY, y2: goalY, class: 'web-plan-line' }));
    legend.append(legendItem(kit, 'var(--label)', kit.t('dailyGoal', { value: kit.format(goal, daily.format) }), true));
  }
  const axis = kit.element('div', 'web-axis-row');
  [0, Math.floor(days / 2), days - 1].forEach((index) => axis.append(kit.element('span', '', kit.day(values[index].key, { day: 'numeric', month: 'short' }))));
  slot('daily').replaceChildren(chart, axis, legend);
}

function renderHistory(snapshot, kit) {
  const months = snapshot.history ?? [];
  if (!block('history', months.length > 1)) return;
  const max = Math.max(...months.map((month) => Number(month.value) || 0), 1);
  const width = 640;
  const height = 150;
  const slotWidth = width / months.length;
  const barWidth = Math.min(slotWidth / 2.5, 36);
  const chart = svg('svg', { viewBox: `0 0 ${width} ${height}`, role: 'img', 'aria-label': kit.t('historyTitle'), class: 'web-svg' });
  const axis = kit.element('div', 'web-axis-row months');
  axis.style.gridTemplateColumns = `repeat(${months.length}, minmax(0, 1fr))`;
  const monthName = new Intl.DateTimeFormat(kit.locale, { month: 'short' });
  months.forEach((month, index) => {
    const value = Number(month.value) || 0;
    const barHeight = Math.max((value / max) * height, 1);
    const rect = svg('rect', { x: index * slotWidth + (slotWidth - barWidth) / 2, y: height - barHeight, width: barWidth, height: barHeight, rx: Math.min(barWidth / 2, 4) });
    rect.style.fill = index === months.length - 1 ? 'var(--tint)' : 'color-mix(in srgb, var(--tint) 45%, transparent)';
    const title = svg('title');
    title.textContent = kit.format(value, month.format);
    rect.append(title);
    chart.append(rect);
    const [year, number] = String(month.month).split('-').map(Number);
    axis.append(kit.element('span', index === months.length - 1 ? 'current' : '', monthName.format(new Date(year, number - 1, 1))));
  });
  slot('history').replaceChildren(chart, axis);
}
