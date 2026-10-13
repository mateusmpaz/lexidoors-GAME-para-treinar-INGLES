extends AudioStreamPlayer

func play_cue(kind: String) -> void:
	var notes: Array = [440.0]
	match kind:
		"success": notes = [523.25, 659.25, 783.99, 1046.5]
		"failure": notes = [220.0, 174.61, 130.81]
		"door": notes = [130.81, 196.0]
		"hint": notes = [659.25, 783.99]
	var sample_rate := 22050
	var duration := 0.14
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * notes.size() * 2)
	for n in notes.size():
		for i in count:
			var t := float(i) / sample_rate
			var envelope := sin(PI * float(i) / count) * exp(-t * 9)
			var wave := sin(TAU * float(notes[n]) * t) + 0.18 * sin(TAU * float(notes[n]) * 2 * t)
			bytes.encode_s16((n * count + i) * 2, int(wave * envelope * 5200))
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = sample_rate
	sample.data = bytes
	stream = sample
	play()
