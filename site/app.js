(function () {
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var darkMode = window.matchMedia("(prefers-color-scheme: dark)");
  var names = ["tint", "ink", "mustard", "orange", "rust", "olive", "teal", "denim", "plum", "brown", "cream"];
  var cache = {};
  var players = new Map();

  function rgba(name) {
    var probe = document.createElement("i");
    probe.style.color = "var(--" + name + ")";
    document.body.appendChild(probe);
    var parts = getComputedStyle(probe).color.match(/[\d.]+/g).map(Number);
    probe.remove();
    return [parts[0] / 255, parts[1] / 255, parts[2] / 255, 1];
  }

  function palette() {
    var colors = {};
    names.forEach(function (name) { colors[name] = rgba(name); });
    return colors;
  }

  function recolor(items, color) {
    items.forEach(function (item) {
      if (item.ty === "fl" || item.ty === "st") item.c.k = color;
      if (item.it) recolor(item.it, color);
    });
  }

  function fetchAnimation(name) {
    if (!cache[name]) {
      cache[name] = fetch("/animations/" + name + ".json").then(function (response) { return response.text(); });
    }
    return cache[name];
  }

  function play(stage) {
    if (!window.lottie || players.has(stage) || stage.closest("[hidden]")) return;
    players.set(stage, null);
    var colors = palette();
    fetchAnimation(stage.dataset.animation).then(function (text) {
      var data = JSON.parse(text);
      data.layers.forEach(function (layer) {
        if (colors[layer.nm] && layer.shapes) recolor(layer.shapes, colors[layer.nm]);
      });
      var player = window.lottie.loadAnimation({
        container: stage,
        renderer: "svg",
        loop: !reduceMotion.matches,
        autoplay: !reduceMotion.matches,
        animationData: data
      });
      if (reduceMotion.matches) {
        player.addEventListener("DOMLoaded", function () { player.goToAndStop(player.totalFrames - 1, true); });
      }
      players.set(stage, player);
    });
  }

  function playVisible() {
    document.querySelectorAll("[data-animation]").forEach(play);
  }

  function reset() {
    players.forEach(function (player) { if (player) player.destroy(); });
    players.clear();
    playVisible();
  }

  function fill(scope) {
    var bars = scope.querySelectorAll(".bar:not(.filled)");
    if (!("IntersectionObserver" in window) || reduceMotion.matches) {
      bars.forEach(function (bar) { bar.classList.add("filled"); });
      return;
    }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("filled");
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });
    bars.forEach(function (bar) { observer.observe(bar); });
  }

  function setUpTabs() {
    var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
    function select(tab) {
      tabs.forEach(function (other) {
        var selected = other === tab;
        other.setAttribute("aria-selected", String(selected));
        other.tabIndex = selected ? 0 : -1;
        document.getElementById(other.getAttribute("aria-controls")).hidden = !selected;
      });
      var panel = document.getElementById(tab.getAttribute("aria-controls"));
      panel.querySelectorAll("[data-animation]").forEach(play);
      fill(panel);
    }
    tabs.forEach(function (tab, index) {
      tab.addEventListener("click", function () { select(tab); });
      tab.addEventListener("keydown", function (event) {
        var step = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
        if (!step) return;
        event.preventDefault();
        var next = tabs[(index + step + tabs.length) % tabs.length];
        next.focus();
        select(next);
      });
    });
  }

  function setUpFilters() {
    var buttons = document.querySelectorAll("[data-filter]");
    buttons.forEach(function (button) {
      button.addEventListener("click", function () {
        var topic = button.dataset.filter;
        buttons.forEach(function (other) { other.setAttribute("aria-pressed", String(other === button)); });
        document.querySelectorAll(".tip").forEach(function (tip) {
          tip.hidden = topic !== "all" && tip.dataset.topic !== topic;
        });
        fill(document.querySelector(".tip-grid"));
      });
    });
  }

  setUpTabs();
  setUpFilters();
  playVisible();
  fill(document);
  darkMode.addEventListener("change", reset);
  reduceMotion.addEventListener("change", reset);
})();
