extends RefCounted
## Synthesize a short cue once and play it through the game's existing SFX
## manager. PCM WAV supports Web sample playback without a live generator.

static func tone(frequency_hz: float = 440.0, duration_seconds: float = 0.12, gain: float = 0.2, end_frequency_hz: float = -1.0, sample_rate: int = 22050) -> AudioStreamWAV:
	var rate: int = clampi(sample_rate, 8000, 48000)
	var duration: float = clampf(duration_seconds if is_finite(duration_seconds) else 0.12, 0.01, 2.0)
	var amplitude: float = clampf(gain if is_finite(gain) else 0.0, 0.0, 1.0)
	var start_hz: float = clampf(frequency_hz if is_finite(frequency_hz) else 440.0, 20.0, float(rate) * 0.45)
	var end_hz: float = clampf(end_frequency_hz, 20.0, float(rate) * 0.45) if is_finite(end_frequency_hz) and end_frequency_hz > 0.0 else start_hz
	var frames: int = maxi(2, roundi(duration * rate))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase: float = 0.0
	var attack_frames: float = minf(rate * 0.005, frames * 0.25)
	var release_frames: float = minf(rate * 0.015, frames * 0.5)
	for index in range(frames):
		var progress: float = float(index) / float(frames - 1)
		var envelope: float = minf(1.0, minf(index / attack_frames, (frames - 1 - index) / release_frames))
		var sample: int = roundi(sin(phase) * amplitude * envelope * 32767.0)
		bytes.encode_s16(index * 2, sample)
		phase += TAU * lerpf(start_hz, end_hz, progress) / float(rate)
	return _wav(bytes, rate, false)


## Filtered noise. looped stitches the end into the start so a bed can repeat.
static func noise(duration_seconds: float = 0.2, gain: float = 0.1, brightness: float = 0.4, looped: bool = false, sample_rate: int = 22050) -> AudioStreamWAV:
	var rate: int = clampi(sample_rate, 8000, 48000)
	var duration: float = clampf(duration_seconds if is_finite(duration_seconds) else 0.2, 0.05, 2.0)
	var amplitude: float = clampf(gain if is_finite(gain) else 0.0, 0.0, 1.0)
	var coeff: float = clampf(brightness if is_finite(brightness) else 0.4, 0.02, 0.95)
	var frames: int = maxi(8, roundi(duration * rate))
	var fade := mini(int(rate * 0.04), int(frames / 4)) if looped else 0
	var total := frames + fade
	var samples := PackedFloat32Array()
	samples.resize(total)
	var state := 12345
	var low := 0.0
	var slow := 0.0
	var attack_frames: float = minf(rate * 0.008, frames * 0.25)
	var release_frames: float = minf(rate * 0.05, frames * 0.45)
	for index in range(total):
		state = int((state * 1103515245 + 12345) % 2147483647)
		var white := float(state % 65536) / 32768.0 - 1.0
		low += coeff * (white - low)
		slow += 0.1 * (low - slow)
		var envelope := 1.0
		if not looped:
			envelope = minf(1.0, minf(index / attack_frames, (frames - 1 - index) / release_frames))
		samples[index] = (low - slow) * amplitude * envelope
	if fade > 0:
		for index in fade:
			var mix: float = float(index) / float(fade)
			samples[index] = lerpf(samples[frames + index], samples[index], mix)
	return _wav(_pcm(samples, frames), rate, looped)


## Short crack plus a falling rumble for the moment a bolt lands.
static func thunder(sample_rate: int = 22050) -> AudioStreamWAV:
	var rate: int = clampi(sample_rate, 8000, 48000)
	var frames: int = maxi(8, roundi(0.5 * rate))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var state := 12345
	var low := 0.0
	var phase := 0.0
	for index in range(frames):
		state = int((state * 1103515245 + 12345) % 2147483647)
		var white := float(state % 65536) / 32768.0 - 1.0
		low += 0.22 * (white - low)
		var progress: float = float(index) / float(frames - 1)
		var crack := exp(-progress * 26.0)
		var body := exp(-progress * 3.0)
		var attack := minf(1.0, float(index) / maxf(1.0, rate * 0.004))
		var sample := (low * crack * 0.5 + sin(phase) * body * 0.4) * attack
		bytes.encode_s16(index * 2, clampi(roundi(sample * 32767.0), -32767, 32767))
		phase += TAU * lerpf(96.0, 38.0, progress) / float(rate)
	return _wav(bytes, rate, false)


static func _pcm(samples: PackedFloat32Array, frames: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for index in range(frames):
		bytes.encode_s16(index * 2, clampi(roundi(samples[index] * 32767.0), -32767, 32767))
	return bytes


static func _wav(bytes: PackedByteArray, sample_rate: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
	if looped:
		stream.loop_begin = 0
		stream.loop_end = bytes.size() / 2
	return stream
