(function () {
  var locales = {
    "en-US": { language: "en", name: "English", currency: "USD", rate: 1 },
    "pt-BR": { language: "pt-BR", name: "Português (Brasil)", currency: "BRL", rate: 5 },
    "es-ES": { language: "es", name: "Español", currency: "EUR", rate: 0.92 },
    "de-DE": { language: "de", name: "Deutsch", currency: "EUR", rate: 0.92 },
    "fr-FR": { language: "fr", name: "Français", currency: "EUR", rate: 0.92 },
    "it-IT": { language: "it", name: "Italiano", currency: "EUR", rate: 0.92 },
    "ja-JP": { language: "ja", name: "日本語", currency: "JPY", rate: 150, step: 10 },
    "ko-KR": { language: "ko", name: "한국어", currency: "KRW", rate: 1400, step: 10 },
    "zh-CN": { language: "zh-Hans", name: "简体中文", currency: "CNY", rate: 7.2 },
    "ru-RU": { language: "ru", name: "Русский", currency: "RUB", rate: 95 }
  };
  var codes = Object.keys(locales);

  function resolve(value) {
    if (!value) return null;
    var wanted = String(value).trim().replace(/_/g, "-").toLowerCase();
    if (!wanted) return null;
    for (var i = 0; i < codes.length; i++) {
      if (codes[i].toLowerCase() === wanted || locales[codes[i]].language.toLowerCase() === wanted) return codes[i];
    }
    var language = wanted.split("-")[0];
    for (var j = 0; j < codes.length; j++) {
      if (codes[j].split("-")[0].toLowerCase() === language) return codes[j];
    }
    return null;
  }

  function fromBrowser() {
    var preferred = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    for (var i = 0; i < preferred.length; i++) {
      var code = resolve(preferred[i]);
      if (code) return code;
    }
    return null;
  }

  var explicit = resolve(new URLSearchParams(location.search).get("locale"));
  var locale = explicit || fromBrowser() || "en-US";
  var config = locales[locale];
  var root = document.documentElement;
  root.lang = locale;
  root.dir = "ltr";

  var revealed = false;
  function reveal() {
    if (revealed) return;
    revealed = true;
    root.classList.remove("i18n-pending");
  }

  var strings = null;
  if (config.language !== "en") {
    root.classList.add("i18n-pending");
    setTimeout(reveal, 800);
    strings = fetch("/i18n/" + config.language + ".json").then(function (response) {
      if (!response.ok) throw new Error(response.status);
      return response.json();
    });
  }

  var ready = new Promise(function (done) {
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", done);
    else done();
  });

  function each(selector, action) {
    Array.prototype.forEach.call(document.querySelectorAll(selector), action);
  }

  function fill(element, value) {
    if (/\{\w+\}/.test(value)) {
      var slots = {};
      Array.prototype.forEach.call(element.children, function (child) {
        if (child.dataset.slot) slots[child.dataset.slot] = child;
      });
      element.textContent = "";
      value.split(/(\{\w+\})/).forEach(function (part) {
        var slot = /^\{(\w+)\}$/.exec(part);
        if (slot && slots[slot[1]]) element.appendChild(slots[slot[1]]);
        else if (part) element.appendChild(document.createTextNode(part));
      });
      return;
    }
    if (!element.children.length) {
      element.textContent = value;
      return;
    }
    var placed = false;
    Array.prototype.slice.call(element.childNodes).forEach(function (node) {
      if (node.nodeType !== 3) return;
      if (!placed && node.nodeValue.trim()) {
        node.nodeValue = value;
        placed = true;
      } else {
        node.remove();
      }
    });
    if (!placed) element.appendChild(document.createTextNode(value));
  }

  function translate(dictionary) {
    each("[data-i18n]", function (element) {
      var value = dictionary[element.dataset.i18n];
      if (typeof value === "string") fill(element, value);
    });
    each("[data-i18n-html]", function (element) {
      var value = dictionary[element.dataset.i18nHtml];
      if (typeof value === "string") element.innerHTML = value;
    });
    ["content", "aria-label", "alt"].forEach(function (attribute) {
      each("[data-i18n-" + attribute + "]", function (element) {
        var value = dictionary[element.getAttribute("data-i18n-" + attribute)];
        if (typeof value === "string") element.setAttribute(attribute, value);
      });
    });
    each(".notice[hidden]", function (element) { element.hidden = false; });
  }

  function money(raw) {
    var cents = raw.indexOf(".") >= 0;
    var value = parseFloat(raw) * config.rate;
    var digits = cents && !config.step ? 2 : 0;
    value = config.step ? Math.round(value / config.step) * config.step : Number(value.toFixed(digits));
    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: config.currency,
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
      signDisplay: raw.charAt(0) === "+" ? "always" : "auto"
    }).format(value).replace("-", "−");
  }

  function parseDate(raw) {
    var parts = raw.split(/[-T:]/).map(Number);
    return new Date(parts[0], parts[1] - 1, parts[2] || 1, parts[3] || 0, parts[4] || 0);
  }

  function clock(date) {
    return new Intl.DateTimeFormat(locale, { hour: "numeric", minute: "2-digit" }).formatToParts(date)
      .filter(function (part) { return part.type !== "dayPeriod"; })
      .map(function (part) { return part.value; }).join("").trim();
  }

  function shortDay(date) {
    return new Intl.DateTimeFormat(locale, { weekday: "short", month: "short", day: "numeric" }).format(date).replace(/,\s*/g, " ");
  }

  var dateFormats = {
    long: function (date) {
      return new Intl.DateTimeFormat(locale, { year: "numeric", month: "long", day: "numeric" }).format(date);
    },
    monthUpper: function (date) {
      return new Intl.DateTimeFormat(locale, { year: "numeric", month: "long" }).format(date).toLocaleUpperCase(locale);
    },
    clock: clock,
    menubar: function (date) {
      return shortDay(date) + "  " + new Intl.DateTimeFormat(locale, { hour: "numeric", minute: "2-digit" }).format(date);
    },
    statusbar: function (date) {
      return clock(date) + "  " + shortDay(date);
    }
  };

  function format() {
    each("[data-money]", function (element) { element.textContent = money(element.dataset.money); });
    each("[data-number]", function (element) {
      element.textContent = new Intl.NumberFormat(locale).format(Number(element.dataset.number));
    });
    each("[data-percent]", function (element) {
      element.textContent = new Intl.NumberFormat(locale, { style: "percent" }).format(Number(element.dataset.percent));
    });
    each("[data-date]", function (element) {
      var formatter = dateFormats[element.dataset.format] || dateFormats.long;
      element.textContent = formatter(parseDate(element.dataset.date));
    });
  }

  function overflows(element) {
    var range = document.createRange();
    range.selectNodeContents(element);
    return range.getBoundingClientRect().width > element.getBoundingClientRect().width + 0.01;
  }

  function shrink(target, probe) {
    target.style.fontSize = "";
    var size = parseFloat(getComputedStyle(target).fontSize);
    var smallest = size * 0.6;
    while (overflows(probe) && size > smallest) {
      size -= 0.5;
      target.style.fontSize = size + "px";
    }
  }

  function fit() {
    each(".figures strong", function (element) { shrink(element, element); });
    each(".budget-top", function (row) {
      if (row.children.length === 2) shrink(row.children[1], row.children[0]);
    });
  }

  function link() {
    each("[data-locale-name]", function (element) { element.textContent = config.name; });
    each("[data-locale]", function (element) {
      if (element.dataset.locale === locale) element.setAttribute("aria-current", "true");
      else element.removeAttribute("aria-current");
    });
    if (!explicit) return;
    each('a[href^="/"]', function (element) {
      var url = new URL(element.getAttribute("href"), location.origin);
      url.searchParams.set("locale", locale);
      element.setAttribute("href", url.pathname + url.search + url.hash);
    });
  }

  function closePickerOnOutsideClick() {
    document.addEventListener("click", function (event) {
      each(".locale-picker[open]", function (picker) {
        if (!picker.contains(event.target)) picker.removeAttribute("open");
      });
    });
  }

  ready.then(function () {
    format();
    link();
    fit();
    closePickerOnOutsideClick();
    window.addEventListener("load", fit);
    if (document.fonts) document.fonts.ready.then(fit);
    var pending;
    window.addEventListener("resize", function () {
      clearTimeout(pending);
      pending = setTimeout(fit, 150);
    });
  });

  if (strings) {
    Promise.all([strings, ready]).then(function (results) {
      translate(results[0]);
      format();
      link();
      fit();
      reveal();
    }).catch(reveal);
  }
})();
