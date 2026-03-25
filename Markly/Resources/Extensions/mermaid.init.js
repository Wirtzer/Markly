// init mermaid (v11 async API)

(function () {

  mermaid.initialize({
    startOnLoad: false,
    flowchart: {
      htmlLabels: false,
      useMaxWidth: true
    },
    securityLevel: 'loose'
  });

  var init = async function() {
    var domAll = document.querySelectorAll(".language-mermaid");
    for (var i = 0; i < domAll.length; i++) {
      var dom = domAll[i];
      var graphSource = dom.innerText || dom.textContent;

      // Walk up to the <pre> wrapper (or its parent) so we replace the whole block
      var target = dom.parentElement;
      if (target.tagName === "PRE") {
        target = target.parentElement;
      }

      try {
        // Mermaid v10+ uses an async render API that returns { svg }
        var result = await mermaid.render('graphDiv' + i, graphSource);
        target.innerHTML = result.svg;
      } catch(e) {
        console.log("Mermaid error: " + e);
      }
    }
  };

  // Run on load and also after a short delay for loadHTMLString
  if (typeof window.addEventListener != "undefined") {
    window.addEventListener("load", function() { init(); }, false);
  }

  // Also run after DOM is ready and after a delay as fallback
  if (document.readyState === "complete" || document.readyState === "interactive") {
    setTimeout(init, 100);
  } else {
    document.addEventListener("DOMContentLoaded", function() {
      setTimeout(init, 100);
    });
  }
})();
