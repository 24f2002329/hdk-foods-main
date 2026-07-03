import 'dart:js' as js;

void playAlertSound() {
  try {
    js.context.callMethod('eval', ["""
      (function() {
        try {
          var context = new (window.AudioContext || window.webkitAudioContext)();
          var osc = context.createOscillator();
          var gain = context.createGain();
          osc.connect(gain);
          gain.connect(context.destination);
          
          // Two-tone chime: High pitch followed by lower decay
          osc.type = 'sine';
          osc.frequency.setValueAtTime(880, context.currentTime); // A5
          osc.frequency.setValueAtTime(1100, context.currentTime + 0.15); // C#6
          
          gain.gain.setValueAtTime(0.01, context.currentTime);
          gain.gain.linearRampToValueAtTime(0.3, context.currentTime + 0.05);
          gain.gain.exponentialRampToValueAtTime(0.01, context.currentTime + 0.6);
          
          osc.start(context.currentTime);
          osc.stop(context.currentTime + 0.6);
        } catch (e) {
          console.error('Failed to synthesize chime:', e);
        }
      })()
    """]);
  } catch (e) {
    // Fallback/Silent in environments where js interop fails
  }
}
