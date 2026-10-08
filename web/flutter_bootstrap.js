{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  // Flutter's cleanup worker retires the old online preview cache.
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine();
    await runner.runApp();
    document.getElementById('loading')?.remove();
  }
});
