/**
 * Barcode Scanner Hook for Phoenix LiveView
 * Supports both webcam and smartphone cameras
 * Uses html5-qrcode library (loaded via CDN) for scanning
 */
export const BarcodeScanner = {
  mounted() {
    this.scanner = null;
    this.isScanning = false;
    this.config = {
      fps: 10, // Frames per second
      qrbox: 250, // Scanning area size
      aspectRatio: 1.0,
      disableFlip: false,
      videoConstraints: {
        facingMode: "environment",
      },
    };

    // Get DOM elements
    this.videoContainer = this.el.querySelector("#scanner-video");
    this.startBtn = this.el.querySelector("#start-scanner-btn");
    this.stopBtn = this.el.querySelector("#stop-scanner-btn");
    this.switchBtn = this.el.querySelector("#switch-camera-btn");
    this.currentCameraId = null;
    this.cameras = [];

    // Bind event listeners
    this.startBtn?.addEventListener("click", () => this.startScanning());
    this.stopBtn?.addEventListener("click", () => this.stopScanning());
    this.switchBtn?.addEventListener("click", () => this.switchCamera());

    // Initialize scanner
    this.initScanner();

    // Handle LiveView events
    this.handleEvent("stop_scanner", () => this.stopScanning());
  },

  destroyed() {
    this.stopScanning();
  },

  async initScanner() {
    try {
      // Check if Html5Qrcode is available (loaded from CDN)
      if (typeof Html5Qrcode === "undefined") {
        console.error("Html5Qrcode library not loaded");
        this.pushEvent("scanner_error", {
          error: "Scanner library not loaded. Please refresh the page.",
        });
        return;
      }

      this.scanner = new Html5Qrcode("scanner-video");

      // Get available cameras
      try {
        const devices = await Html5Qrcode.getCameras();
        this.cameras = devices;

        // Show/hide switch camera button based on camera count
        if (this.switchBtn) {
          this.switchBtn.style.display = devices.length > 1 ? "block" : "none";
        }

        // Prefer back camera on mobile
        this.currentCameraId = this.getPreferredCamera(devices);

        console.log(`Found ${devices.length} camera(s)`);
      } catch (err) {
        console.error("Failed to get cameras:", err);
        // Even if we can't enumerate cameras, we can still try to start with default
        this.cameras = [];
        this.currentCameraId = { facingMode: "environment" }; // Use environment facing camera
      }
    } catch (err) {
      console.error("Failed to initialize scanner:", err);
      this.pushEvent("scanner_error", {
        error: "Failed to initialize camera. Please check permissions.",
      });
    }
  },

  getPreferredCamera(devices) {
    // Try to find back camera (usually better for scanning)
    const backCamera = devices.find(
      (device) =>
        device.label.toLowerCase().includes("back") ||
        device.label.toLowerCase().includes("rear")
    );

    if (backCamera) {
      return backCamera.id;
    }

    // Otherwise use first available
    return devices[0]?.id;
  },

  async startScanning() {
    if (this.isScanning || !this.scanner) {
      return;
    }

    try {
      console.log("Starting scanner with camera:", this.currentCameraId);
      console.log("Config:", this.config);

      // Try to start with the selected camera
      await this.scanner.start(
        this.currentCameraId,
        this.config,
        (decodedText, decodedResult) => {
          // Successfully scanned
          this.handleScan(decodedText, decodedResult);
        },
        (errorMessage) => {
          // Scanning error (can be ignored, happens frequently)
          // console.log("Scan error:", errorMessage);
        }
      );

      this.isScanning = true;
      this.updateUI(true);
      this.pushEvent("scanner_started", {});

      console.log("Scanner started successfully");
      console.log("Scanner state:", this.scanner.getState());
    } catch (err) {
      console.error("Failed to start scanner:", err);

      // Provide more specific error messages
      let errorMsg = "Failed to start camera. ";

      if (
        err.message.includes("NotReadableError") ||
        err.message.includes("Could not start video source")
      ) {
        errorMsg +=
          "The camera may be in use by another application. Please close other apps using the camera and try again.";
      } else if (
        err.message.includes("NotAllowedError") ||
        err.message.includes("Permission")
      ) {
        errorMsg +=
          "Camera permission denied. Please allow camera access in your browser settings.";
      } else if (err.message.includes("NotFoundError")) {
        errorMsg += "No camera found on this device.";
      } else {
        errorMsg += err.message || "Unknown error occurred.";
      }

      this.pushEvent("scanner_error", { error: errorMsg });
    }
  },

  async stopScanning() {
    if (!this.isScanning || !this.scanner) {
      return;
    }

    try {
      await this.scanner.stop();
      this.isScanning = false;
      this.updateUI(false);
      this.pushEvent("scanner_stopped", {});

      console.log("Scanner stopped");
    } catch (err) {
      console.error("Failed to stop scanner:", err);
    }
  },

  async switchCamera() {
    if (this.cameras.length <= 1) {
      return;
    }

    const currentIndex = this.cameras.findIndex(
      (cam) => cam.id === this.currentCameraId
    );
    const nextIndex = (currentIndex + 1) % this.cameras.length;
    this.currentCameraId = this.cameras[nextIndex].id;

    if (this.isScanning) {
      await this.stopScanning();
      setTimeout(() => this.startScanning(), 500);
    }
  },

  handleScan(decodedText, decodedResult) {
    // Play beep sound (optional)
    this.playBeep();

    // Send scanned barcode to LiveView
    this.pushEvent("barcode_scanned", {
      barcode: decodedText,
      format: decodedResult.result.format.formatName,
    });

    // Auto-stop after successful scan (optional, can be removed if you want continuous scanning)
    setTimeout(() => {
      this.stopScanning();
    }, 300);
  },

  updateUI(isScanning) {
    if (this.startBtn) {
      this.startBtn.style.display = isScanning ? "none" : "block";
    }
    if (this.stopBtn) {
      this.stopBtn.style.display = isScanning ? "block" : "none";
    }
    if (this.switchBtn && this.cameras.length > 1) {
      this.switchBtn.disabled = !isScanning;
    }
  },

  playBeep() {
    // Create a simple beep sound
    const audioContext = new (window.AudioContext ||
      window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.value = 800;
    oscillator.type = "sine";
    gainNode.gain.value = 0.3;

    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.1);
  },
};
