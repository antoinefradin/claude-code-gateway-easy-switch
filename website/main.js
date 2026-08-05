/* ccgs landing page — scroll reveal, copy button, before/after toggle, console tabs.
 * No dependencies. Hidden states live behind .js-reveal on <html>, added here so the
 * page is fully visible without JavaScript. Reduced motion is handled in CSS. */

(function () {
  "use strict";

  /* ---- scroll reveal ---- */
  function initReveal() {
    var targets = document.querySelectorAll("[data-reveal]");
    if (!("IntersectionObserver" in window)) {
      targets.forEach(function (el) { el.classList.add("is-in"); });
      return;
    }
    document.documentElement.classList.add("js-reveal");
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-in");
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -10% 0px", threshold: 0.05 }
    );
    targets.forEach(function (el) { observer.observe(el); });
  }

  /* ---- copy-to-clipboard install line ---- */
  function initCopy() {
    document.querySelectorAll("[data-copy]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var text = btn.getAttribute("data-copy");
        var done = function () {
          btn.classList.add("is-copied");
          window.setTimeout(function () { btn.classList.remove("is-copied"); }, 1800);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, done);
        } else {
          var ta = document.createElement("textarea");
          ta.value = text;
          ta.style.position = "fixed";
          ta.style.opacity = "0";
          document.body.appendChild(ta);
          ta.select();
          try { document.execCommand("copy"); } catch (e) { /* noop */ }
          document.body.removeChild(ta);
          done();
        }
      });
    });
  }

  /* ---- before/after toggle ---- */
  function initToggle() {
    document.querySelectorAll(".demo").forEach(function (demo) {
      var buttons = demo.querySelectorAll(".switch button");
      var tally = demo.querySelector(".demo-tally span");
      var verdict = demo.querySelector(".demo-verdict");
      if (buttons.length < 2) return;

      var copy = {
        without: {
          tally: "4 manual edits · 1 fragile file",
          verdict: "One bad edit and the whole file stops parsing.",
        },
        with: {
          tally: "1 command · settings.json intact",
          verdict: "ccgs proxy litellm — and only its four keys moved.",
        },
      };

      function set(mode) {
        demo.setAttribute("data-mode", mode);
        buttons.forEach(function (b, i) {
          var active = (mode === "without") ? i === 0 : i === 1;
          b.classList.toggle("is-active", active);
          b.setAttribute("aria-pressed", String(active));
        });
        if (tally) {
          tally.style.animation = "none";
          /* force reflow so the fade replays */
          void tally.offsetWidth;
          tally.style.animation = "";
          tally.textContent = copy[mode].tally;
        }
        if (verdict) verdict.textContent = copy[mode].verdict;
      }

      buttons[0].addEventListener("click", function () { set("without"); });
      buttons[1].addEventListener("click", function () { set("with"); });
    });
  }

  /* ---- console tabs ---- */
  function initTabs() {
    var tablist = document.querySelector(".console-tablist");
    if (!tablist) return;
    var tabs = Array.prototype.slice.call(tablist.querySelectorAll('[role="tab"]'));
    var underline = tablist.querySelector(".console-underline");

    function moveUnderline(tab) {
      if (!underline) return;
      underline.style.width = tab.offsetWidth + "px";
      underline.style.translate = tab.offsetLeft + "px 0";
    }

    function activate(tab, focus) {
      tabs.forEach(function (t) {
        var selected = t === tab;
        t.setAttribute("aria-selected", String(selected));
        t.setAttribute("tabindex", selected ? "0" : "-1");
        t.classList.toggle("is-active", selected);
        var panel = document.getElementById(t.getAttribute("aria-controls"));
        if (panel) panel.hidden = !selected;
      });
      moveUnderline(tab);
      if (focus) tab.focus();
    }

    tabs.forEach(function (tab, i) {
      tab.addEventListener("click", function () { activate(tab); });
      tab.addEventListener("keydown", function (e) {
        var next = null;
        if (e.key === "ArrowRight") next = tabs[(i + 1) % tabs.length];
        else if (e.key === "ArrowLeft") next = tabs[(i - 1 + tabs.length) % tabs.length];
        else if (e.key === "Home") next = tabs[0];
        else if (e.key === "End") next = tabs[tabs.length - 1];
        if (next) { e.preventDefault(); activate(next, true); }
      });
    });

    var current = tablist.querySelector('[aria-selected="true"]') || tabs[0];
    /* underline needs layout; set after first paint and on resize */
    window.requestAnimationFrame(function () { moveUnderline(current); });
    window.addEventListener("resize", function () {
      var sel = tablist.querySelector('[aria-selected="true"]');
      if (sel) moveUnderline(sel);
    });
  }

  function init() {
    initReveal();
    initCopy();
    initToggle();
    initTabs();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
