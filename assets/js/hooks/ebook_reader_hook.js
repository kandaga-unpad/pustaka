export const EbookReader = {
  mounted() {
    this.fileUrl = this.el.dataset.fileUrl;
    this.fileType = this.el.dataset.fileType; // "pdf" or "epub"

    // Create main container structure
    this.createReaderContainer();

    // Wait for libraries to load before initializing
    if (this.fileType === "pdf") {
      this.waitForPDFJS(() => this.renderPDF());
    } else if (this.fileType === "epub") {
      this.waitForEpubJS(() => this.renderEPUB());
    }
  },

  waitForPDFJS(callback) {
    const checkPDFJS = () => {
      console.log("Checking for PDF.js...", {
        pdfjsLib: window.pdfjsLib,
        retry: this.pdfRetries || 0,
      });

      if (window.pdfjsLib) {
        console.log("PDF.js loaded successfully!");
        // Set PDF.js worker - use cdnjs
        if (!window.pdfjsLib.GlobalWorkerOptions.workerSrc) {
          window.pdfjsLib.GlobalWorkerOptions.workerSrc =
            "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";
        }
        callback();
      } else if (this.pdfRetries < 100) {
        // Increased retries to 100 (10 seconds total) to wait for fallback
        this.pdfRetries = (this.pdfRetries || 0) + 1;
        setTimeout(checkPDFJS, 100);
      } else {
        console.error("PDF.js failed to load after 100 retries");
        console.error(
          "Please check: 1) Internet connection, 2) Firewall settings, 3) Browser console for CDN errors"
        );
        this.showError(
          "PDF.js library failed to load from all CDN sources. Please check your internet connection or try a different browser."
        );
      }
    };
    checkPDFJS();
  },

  waitForEpubJS(callback) {
    const checkEpubJS = () => {
      if (window.ePub) {
        callback();
      } else if (this.epubRetries < 50) {
        // Increased retries to 50 (5 seconds total)
        this.epubRetries = (this.epubRetries || 0) + 1;
        setTimeout(checkEpubJS, 100);
      } else {
        console.error("ePub.js failed to load after 50 retries");
        this.showError(
          "ePub.js library failed to load. Please check your internet connection and refresh the page."
        );
      }
    };
    checkEpubJS();
  },

  destroyed() {
    // Clean up event listeners
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler);
    }
    if (this.rendition) {
      this.rendition.destroy();
    }
  },

  createReaderContainer() {
    this.el.innerHTML = `
      <div class="ebook-reader-wrapper h-full flex flex-col">
        <div id="reader-controls" class="reader-controls flex justify-between items-center p-3 bg-gray-100 dark:bg-gray-800 border-b border-gray-300 dark:border-gray-700">
          <div class="flex gap-2 items-center">
            <button id="font-decrease" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark hidden" title="Decrease font size">A-</button>
            <button id="font-increase" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark hidden" title="Increase font size">A+</button>
            <button id="toc-toggle" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark hidden" title="Table of Contents">TOC</button>
            <span id="zoom-hint" class="text-xs text-gray-500 dark:text-gray-400 hidden ml-2">Ctrl+Wheel to zoom, Drag to pan</span>
          </div>
          <div class="flex gap-2 items-center" id="navigation-controls">
            <button id="zoom-out" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark hidden" title="Zoom out (-)">-</button>
            <span id="zoom-level" class="text-sm font-medium hidden"></span>
            <button id="zoom-in" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark hidden" title="Zoom in (+)">+</button>
          </div>
          <div class="flex gap-2 items-center">
            <button id="prev-page" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark" title="Previous (←)">← Prev</button>
            <span id="page-info" class="text-sm font-medium min-w-[120px] text-center">Loading...</span>
            <button id="next-page" class="px-3 py-1 bg-voile-primary text-white rounded hover:bg-voile-primary-dark" title="Next (→)">Next →</button>
          </div>
        </div>
        <div id="toc-sidebar" class="hidden fixed left-0 top-0 w-64 h-full bg-white dark:bg-gray-900 border-r border-gray-300 dark:border-gray-700 z-50 overflow-y-auto">
          <div class="p-4">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold">Table of Contents</h3>
              <button id="toc-close" class="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300">✕</button>
            </div>
            <div id="toc-content"></div>
          </div>
        </div>
        <div id="reader-content" class="reader-content flex-1 overflow-auto bg-white dark:bg-gray-900 flex items-center justify-center">
          <div class="text-center text-gray-500 dark:text-gray-400">
            <svg class="animate-spin h-12 w-12 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p>Loading reader...</p>
          </div>
        </div>
      </div>
    `;

    this.readerContent = this.el.querySelector("#reader-content");
    this.controlsBar = this.el.querySelector("#reader-controls");
    this.pageInfo = this.el.querySelector("#page-info");
    this.tocSidebar = this.el.querySelector("#toc-sidebar");
    this.tocContent = this.el.querySelector("#toc-content");
  },

  renderPDF() {
    const pdfjsLib = window.pdfjsLib;
    if (!pdfjsLib) {
      this.showError("PDF.js library not loaded");
      return;
    }

    this.pageInfo.textContent = "Loading PDF...";

    // Initialize pan and zoom state
    this.scale = 1.0; // Start at 100%
    this.panX = 0;
    this.panY = 0;
    this.isPanning = false;
    this.startX = 0;
    this.startY = 0;

    const loadingTask = pdfjsLib.getDocument(this.fileUrl);
    loadingTask.promise
      .then((pdf) => {
        this.pdf = pdf;
        this.currentPage = 1;
        this.setupPDFControls();
        this.renderPDFPage(this.currentPage);
      })
      .catch((error) => {
        console.error("Error loading PDF:", error);
        this.showError("Failed to load PDF: " + error.message);
      });
  },

  renderPDFPage(pageNum) {
    this.pdf.getPage(pageNum).then((page) => {
      // Calculate scale to fit both width AND height while maintaining aspect ratio
      const container = this.readerContent;
      const maxWidth = 1280; // 7xl = 80rem = 1280px
      const containerWidth = Math.min(container.clientWidth - 80, maxWidth); // 80px for padding
      const containerHeight = container.clientHeight - 40; // 40px for padding

      // Get the page's natural viewport
      const naturalViewport = page.getViewport({ scale: 1.0 });

      // Calculate scales that fit the page to container width and height
      const scaleToFitWidth = containerWidth / naturalViewport.width;
      const scaleToFitHeight = containerHeight / naturalViewport.height;

      // Use the smaller scale so the entire page fits in the viewport
      const baseScale = Math.min(scaleToFitWidth, scaleToFitHeight);

      // Apply user's zoom on top of the base scale
      const finalScale = baseScale * this.scale;

      const viewport = page.getViewport({ scale: finalScale });

      // Create or reuse canvas container
      let canvasContainer = this.readerContent.querySelector(
        ".pdf-page-container"
      );
      if (!canvasContainer) {
        canvasContainer = document.createElement("div");
        canvasContainer.className = "pdf-page-container relative overflow-auto";
        this.readerContent.innerHTML = "";
        this.readerContent.appendChild(canvasContainer);

        // Add pan and zoom handlers
        this.setupPanAndZoom(canvasContainer);
      }

      const canvas = document.createElement("canvas");
      canvas.className =
        "pdf-canvas shadow-2xl mx-auto block cursor-grab active:cursor-grabbing bg-white dark:bg-gray-100";
      canvas.style.transform = `translate(${this.panX}px, ${this.panY}px)`;
      canvas.style.transition = "transform 0.1s ease-out";
      canvas.style.maxWidth = maxWidth + "px";

      const context = canvas.getContext("2d");
      canvas.height = viewport.height;
      canvas.width = viewport.width;

      const renderContext = {
        canvasContext: context,
        viewport: viewport,
      };

      page.render(renderContext).promise.then(() => {
        canvasContainer.innerHTML = "";
        canvasContainer.appendChild(canvas);
        this.updatePDFPageInfo();

        // Re-attach pan handlers to new canvas
        this.attachPanHandlers(canvas);
      });
    });
  },

  setupPanAndZoom(container) {
    // Mouse wheel zoom
    container.addEventListener(
      "wheel",
      (e) => {
        if (e.ctrlKey || e.metaKey) {
          e.preventDefault();

          const delta = e.deltaY > 0 ? -0.1 : 0.1;
          this.scale = Math.max(0.5, Math.min(this.scale + delta, 5));
          this.renderPDFPage(this.currentPage);
        }
      },
      { passive: false }
    );
  },

  attachPanHandlers(canvas) {
    // Mouse down - start panning
    canvas.addEventListener("mousedown", (e) => {
      if (this.scale > 1) {
        this.isPanning = true;
        this.startX = e.clientX - this.panX;
        this.startY = e.clientY - this.panY;
        canvas.style.cursor = "grabbing";
      }
    });

    // Mouse move - pan
    const onMouseMove = (e) => {
      if (this.isPanning) {
        e.preventDefault();
        this.panX = e.clientX - this.startX;
        this.panY = e.clientY - this.startY;
        canvas.style.transform = `translate(${this.panX}px, ${this.panY}px)`;
      }
    };

    // Mouse up - stop panning
    const onMouseUp = () => {
      if (this.isPanning) {
        this.isPanning = false;
        canvas.style.cursor = "grab";
      }
    };

    document.addEventListener("mousemove", onMouseMove);
    document.addEventListener("mouseup", onMouseUp);

    // Touch support for mobile
    let touchStartX = 0;
    let touchStartY = 0;

    canvas.addEventListener("touchstart", (e) => {
      if (this.scale > 1 && e.touches.length === 1) {
        this.isPanning = true;
        touchStartX = e.touches[0].clientX - this.panX;
        touchStartY = e.touches[0].clientY - this.panY;
      }
    });

    canvas.addEventListener(
      "touchmove",
      (e) => {
        if (this.isPanning && e.touches.length === 1) {
          e.preventDefault();
          this.panX = e.touches[0].clientX - touchStartX;
          this.panY = e.touches[0].clientY - touchStartY;
          canvas.style.transform = `translate(${this.panX}px, ${this.panY}px)`;
        }
      },
      { passive: false }
    );

    canvas.addEventListener("touchend", () => {
      this.isPanning = false;
    });
  },

  setupPDFControls() {
    // Show PDF-specific controls
    this.el.querySelector("#zoom-in").classList.remove("hidden");
    this.el.querySelector("#zoom-out").classList.remove("hidden");
    this.el.querySelector("#zoom-level").classList.remove("hidden");
    this.el.querySelector("#zoom-hint").classList.remove("hidden");

    this.updatePDFPageInfo();

    // Zoom controls
    this.el.querySelector("#zoom-in").addEventListener("click", () => {
      this.scale = Math.min(this.scale + 0.25, 5);
      this.panX = 0; // Reset pan when zooming
      this.panY = 0;
      this.renderPDFPage(this.currentPage);
    });

    this.el.querySelector("#zoom-out").addEventListener("click", () => {
      this.scale = Math.max(this.scale - 0.25, 0.5);
      this.panX = 0; // Reset pan when zooming
      this.panY = 0;
      this.renderPDFPage(this.currentPage);
    });

    // Page navigation
    this.el.querySelector("#prev-page").addEventListener("click", () => {
      if (this.currentPage > 1) {
        this.currentPage--;
        this.panX = 0; // Reset pan when changing pages
        this.panY = 0;
        this.renderPDFPage(this.currentPage);
      }
    });

    this.el.querySelector("#next-page").addEventListener("click", () => {
      if (this.currentPage < this.pdf.numPages) {
        this.currentPage++;
        this.panX = 0; // Reset pan when changing pages
        this.panY = 0;
        this.renderPDFPage(this.currentPage);
      }
    });

    // Keyboard navigation
    this.keyboardHandler = (e) => {
      if (e.key === "ArrowLeft" || e.key === "PageUp") {
        if (this.currentPage > 1) {
          this.currentPage--;
          this.panX = 0;
          this.panY = 0;
          this.renderPDFPage(this.currentPage);
        }
        e.preventDefault();
      } else if (e.key === "ArrowRight" || e.key === "PageDown") {
        if (this.currentPage < this.pdf.numPages) {
          this.currentPage++;
          this.panX = 0;
          this.panY = 0;
          this.renderPDFPage(this.currentPage);
        }
        e.preventDefault();
      } else if (e.key === "+" || e.key === "=") {
        this.scale = Math.min(this.scale + 0.25, 5);
        this.renderPDFPage(this.currentPage);
        e.preventDefault();
      } else if (e.key === "-" || e.key === "_") {
        this.scale = Math.max(this.scale - 0.25, 0.5);
        this.renderPDFPage(this.currentPage);
        e.preventDefault();
      } else if (e.key === "0") {
        // Reset zoom to 100%
        this.scale = 1.0;
        this.panX = 0;
        this.panY = 0;
        this.renderPDFPage(this.currentPage);
        e.preventDefault();
      }
    };
    document.addEventListener("keydown", this.keyboardHandler);
  },

  updatePDFPageInfo() {
    this.pageInfo.textContent = `Page ${this.currentPage} of ${this.pdf.numPages}`;
    this.el.querySelector("#zoom-level").textContent = `${Math.round(
      this.scale * 100
    )}%`;

    // Update button states
    this.el.querySelector("#prev-page").disabled = this.currentPage === 1;
    this.el.querySelector("#next-page").disabled =
      this.currentPage === this.pdf.numPages;
  },

  renderEPUB() {
    const ePub = window.ePub;
    if (!ePub) {
      this.showError("ePub.js library not loaded");
      return;
    }

    this.pageInfo.textContent = "Loading EPUB...";

    try {
      this.book = ePub(this.fileUrl);
      this.fontSize = 100; // percentage

      // Show EPUB-specific controls
      this.el.querySelector("#font-increase").classList.remove("hidden");
      this.el.querySelector("#font-decrease").classList.remove("hidden");
      this.el.querySelector("#toc-toggle").classList.remove("hidden");

      // Render to the content area
      this.rendition = this.book.renderTo(this.readerContent, {
        width: "100%",
        height: "100%",
        spread: "none",
        flow: "paginated",
      });

      this.rendition.display().then(() => {
        this.pageInfo.textContent = "Ready";
      });

      // Load navigation/TOC
      this.book.loaded.navigation.then((nav) => {
        this.toc = nav.toc;
        this.renderTOC();
      });

      // Track location changes
      this.rendition.on("relocated", (location) => {
        this.updateEPUBPageInfo(location);
      });

      this.setupEPUBControls();
    } catch (error) {
      console.error("Error loading EPUB:", error);
      this.showError("Failed to load EPUB: " + error.message);
    }
  },

  setupEPUBControls() {
    // Font size controls
    this.el.querySelector("#font-increase").addEventListener("click", () => {
      this.fontSize = Math.min(this.fontSize + 10, 200);
      this.rendition.themes.fontSize(`${this.fontSize}%`);
    });

    this.el.querySelector("#font-decrease").addEventListener("click", () => {
      this.fontSize = Math.max(this.fontSize - 10, 50);
      this.rendition.themes.fontSize(`${this.fontSize}%`);
    });

    // Navigation
    this.el.querySelector("#prev-page").addEventListener("click", () => {
      this.rendition.prev();
    });

    this.el.querySelector("#next-page").addEventListener("click", () => {
      this.rendition.next();
    });

    // TOC toggle
    this.el.querySelector("#toc-toggle").addEventListener("click", () => {
      this.tocSidebar.classList.toggle("hidden");
    });

    this.el.querySelector("#toc-close").addEventListener("click", () => {
      this.tocSidebar.classList.add("hidden");
    });

    // Keyboard navigation
    this.keyboardHandler = (e) => {
      if (e.key === "ArrowLeft" || e.key === "PageUp") {
        this.rendition.prev();
        e.preventDefault();
      } else if (
        e.key === "ArrowRight" ||
        e.key === "PageDown" ||
        e.key === " "
      ) {
        this.rendition.next();
        e.preventDefault();
      }
    };
    document.addEventListener("keydown", this.keyboardHandler);

    // Apply dark mode if needed
    if (document.documentElement.classList.contains("dark")) {
      this.rendition.themes.default({
        body: {
          background: "#1f2937 !important",
          color: "#f3f4f6 !important",
        },
      });
    }
  },

  renderTOC() {
    if (!this.toc || this.toc.length === 0) {
      this.tocContent.innerHTML =
        '<p class="text-gray-500">No table of contents available</p>';
      return;
    }

    const tocList = document.createElement("ul");
    tocList.className = "space-y-2";

    const renderTOCItem = (item, level = 0) => {
      const li = document.createElement("li");
      li.className = `toc-item pl-${level * 4}`;

      const link = document.createElement("a");
      link.href = "#";
      link.className =
        "block py-1 px-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded text-sm";
      link.textContent = item.label;
      link.addEventListener("click", (e) => {
        e.preventDefault();
        this.rendition.display(item.href);
        this.tocSidebar.classList.add("hidden");
      });

      li.appendChild(link);

      if (item.subitems && item.subitems.length > 0) {
        const sublist = document.createElement("ul");
        sublist.className = "ml-2 mt-1 space-y-1";
        item.subitems.forEach((subitem) => {
          const subli = renderTOCItem(subitem, level + 1);
          sublist.appendChild(subli);
        });
        li.appendChild(sublist);
      }

      return li;
    };

    this.toc.forEach((item) => {
      tocList.appendChild(renderTOCItem(item));
    });

    this.tocContent.innerHTML = "";
    this.tocContent.appendChild(tocList);
  },

  updateEPUBPageInfo(location) {
    const current = location.start.displayed.page;
    const total = location.start.displayed.total;

    if (current && total) {
      this.pageInfo.textContent = `Page ${current} of ${total}`;
    } else {
      // Fallback to percentage
      const percentage = Math.round(location.start.percentage * 100);
      this.pageInfo.textContent = `${percentage}%`;
    }
  },

  showError(message) {
    this.readerContent.innerHTML = `
      <div class="flex items-center justify-center h-full">
        <div class="text-center p-8">
          <div class="text-red-500 text-5xl mb-4">⚠</div>
          <h3 class="text-xl font-semibold mb-2 text-gray-800 dark:text-gray-200">Error Loading Book</h3>
          <p class="text-gray-600 dark:text-gray-400">${message}</p>
        </div>
      </div>
    `;
  },
};
