(function () {
  var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));

  function select(tab) {
    tabs.forEach(function (other) {
      var selected = other === tab;
      other.setAttribute("aria-selected", String(selected));
      other.tabIndex = selected ? 0 : -1;
      document.getElementById(other.getAttribute("aria-controls")).hidden = !selected;
    });
  }

  tabs.forEach(function (tab, index) {
    tab.addEventListener("click", function () { select(tab); });
    tab.addEventListener("keydown", function (event) {
      var step = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
      var edge = event.key === "Home" ? 0 : event.key === "End" ? tabs.length - 1 : -1;
      if (!step && edge < 0) return;
      event.preventDefault();
      var next = edge >= 0 ? tabs[edge] : tabs[(index + step + tabs.length) % tabs.length];
      next.focus();
      select(next);
    });
  });

  var current = tabs.filter(function (tab) { return tab.getAttribute("aria-selected") === "true"; })[0];
  if (current) select(current);
  document.documentElement.classList.add("tabs-ready");
})();
