@tool
class_name GASRetroProfiles
extends RefCounted

const MODERN := "Modern"
const GENERIC_1BIT := "Generic 1-Bit"
const PC_SPEAKER := "DOS PC Speaker"
const ATARI_2600 := "Atari 2600"
const NES := "NES / Famicom"
const GAME_BOY := "Game Boy / GBC"
const MASTER_SYSTEM := "Master System / Game Gear"
const GENESIS := "Mega Drive / Genesis"
const SID := "Commodore 64 SID"
const POKEY := "Atari 8-Bit / POKEY"
const AY := "AY-3-8910"
const AMIGA := "Amiga Paula"
const SNES := "SNES"
const OPL := "DOS AdLib / OPL2"
const ARCADE_FM := "Arcade 4-Op FM"
const FANTASY_RETRO := "Fantasy Retro"

const PROFILE_ORDER: PackedStringArray = [
	MODERN,
	GENERIC_1BIT,
	PC_SPEAKER,
	ATARI_2600,
	NES,
	GAME_BOY,
	MASTER_SYSTEM,
	GENESIS,
	SID,
	POKEY,
	AY,
	AMIGA,
	SNES,
	OPL,
	ARCADE_FM,
	FANTASY_RETRO,
]


static func get_profile(name: String) -> Dictionary:
	match name:
		MODERN:
			return {
				"name": MODERN, "era": "Modern", "sample_rate": 48000,
				"output_bits": 16, "voices": 8, "clock_hz": 0.0,
				"waveforms": ["Sine", "Triangle", "Saw", "Square", "Pulse", "Noise", "FM2", "FM4", "Sample PCM"],
				"description": "Unrestricted modern synthesis for ordinary game audio."
			}
		GENERIC_1BIT:
			return {
				"name": GENERIC_1BIT, "era": "1970s-early 1980s", "sample_rate": 22050,
				"output_bits": 1, "voices": 1, "clock_hz": 0.0,
				"waveforms": ["Square", "Pulse"],
				"description": "Single-bit pulse and square synthesis with no conventional amplitude resolution."
			}
		PC_SPEAKER:
			return {
				"name": PC_SPEAKER, "era": "1980s-1990s DOS", "sample_rate": 22050,
				"output_bits": 1, "voices": 1, "clock_hz": 1193182.0,
				"waveforms": ["Square"],
				"description": "IBM PC speaker-style square tones quantized to the 8253/8254 PIT clock."
			}
		ATARI_2600:
			return {
				"name": ATARI_2600, "era": "1977", "sample_rate": 31440,
				"output_bits": 4, "voices": 2, "clock_hz": 31440.0,
				"waveforms": ["TIA Tone", "TIA Poly4", "TIA Poly5", "TIA Poly9"],
				"description": "TIA-inspired divided tones and polynomial-noise voices."
			}
		NES:
			return {
				"name": NES, "era": "1983/1985", "sample_rate": 44100,
				"output_bits": 7, "voices": 5, "clock_hz": 1789773.0,
				"waveforms": ["NES Pulse", "NES Triangle", "NES Noise", "NES DPCM"],
				"description": "2A03/2A07-style pulse duty cycles, 32-step triangle, timer quantization, LFSR noise, and DPCM-inspired sample playback."
			}
		GAME_BOY:
			return {
				"name": GAME_BOY, "era": "1989-1998", "sample_rate": 44100,
				"output_bits": 4, "voices": 4, "clock_hz": 4194304.0,
				"waveforms": ["GB Pulse", "GB Wave", "GB Noise"],
				"description": "DMG/CGB-style pulse duty voices, 32-sample 4-bit wavetable, and 15/7-bit LFSR noise."
			}
		MASTER_SYSTEM:
			return {
				"name": MASTER_SYSTEM, "era": "1985-1990", "sample_rate": 44100,
				"output_bits": 4, "voices": 4, "clock_hz": 3579545.0,
				"waveforms": ["PSG Square", "PSG Noise"],
				"description": "SN76489-family PSG tones and noise with clock-divider pitch steps."
			}
		GENESIS:
			return {
				"name": GENESIS, "era": "1988-1990", "sample_rate": 53267,
				"output_bits": 9, "voices": 10, "clock_hz": 7670454.0,
				"waveforms": ["FM4", "PSG Square", "PSG Noise"],
				"description": "YM2612-flavored four-operator FM plus SN76489-family PSG synthesis."
			}
		SID:
			return {
				"name": SID, "era": "1982", "sample_rate": 44100,
				"output_bits": 12, "voices": 3, "clock_hz": 985248.0,
				"waveforms": ["SID Triangle", "SID Saw", "SID Pulse", "SID Noise"],
				"description": "Three-voice SID-style oscillators with stepped ADSR, pulse width, ring modulation and resonant filtering."
			}
		POKEY:
			return {
				"name": POKEY, "era": "1979", "sample_rate": 44100,
				"output_bits": 4, "voices": 4, "clock_hz": 1789790.0,
				"waveforms": ["POKEY Tone", "POKEY Poly4", "POKEY Poly5", "POKEY Poly17"],
				"description": "POKEY-style divided tones and polynomial noise with coarse frequency registers."
			}
		AY:
			return {
				"name": AY, "era": "late 1970s-1980s", "sample_rate": 44100,
				"output_bits": 4, "voices": 3, "clock_hz": 1773400.0,
				"waveforms": ["AY Square", "AY Noise"],
				"description": "Three square-wave tone channels with shared noise and hardware-envelope character."
			}
		AMIGA:
			return {
				"name": AMIGA, "era": "1985-1990s", "sample_rate": 28604,
				"output_bits": 8, "voices": 4, "clock_hz": 3546895.0,
				"waveforms": ["Sample Sine", "Sample Saw", "Sample Noise", "Sample Wavetable", "Sample PCM"],
				"description": "Paula-style 8-bit sample playback with period-quantized pitch and four-channel constraints."
			}
		SNES:
			return {
				"name": SNES, "era": "1990-1991", "sample_rate": 32000,
				"output_bits": 16, "voices": 8, "clock_hz": 1024000.0,
				"waveforms": ["Sample Sine", "Sample Saw", "Sample Noise", "Sample Wavetable", "Sample PCM"],
				"description": "SPC700/DSP-era sample synthesis constrained to 32 kHz with short looping source waves and echo-style coloration."
			}
		OPL:
			return {
				"name": OPL, "era": "1987-1990s DOS", "sample_rate": 49716,
				"output_bits": 13, "voices": 9, "clock_hz": 3579545.0,
				"waveforms": ["FM2", "FM4", "OPL Half-Sine", "OPL Abs-Sine"],
				"description": "YM3812/OPL2-style two-operator FM voice architecture and stepped envelope behavior."
			}
		ARCADE_FM:
			return {
				"name": ARCADE_FM, "era": "1980s-1990s arcade", "sample_rate": 55466,
				"output_bits": 14, "voices": 8, "clock_hz": 8000000.0,
				"waveforms": ["FM4"],
				"description": "Four-operator arcade-FM profile with algorithms, feedback, detune and fast envelopes."
			}
		FANTASY_RETRO:
			return {
				"name": FANTASY_RETRO, "era": "Fictional", "sample_rate": 22050,
				"output_bits": 6, "voices": 4, "clock_hz": 0.0,
				"waveforms": ["Square", "Triangle", "Saw", "Pulse", "Noise", "FM2"],
				"description": "Deliberately constrained low-rate synthesis without copying one real machine."
			}
		_:
			return get_profile(MODERN)


static func quantize_frequency(profile_name: String, hz: float, voice: String = "") -> float:
	var f: float = clampf(hz, 20.0, 20000.0)
	match profile_name:
		PC_SPEAKER:
			var divisor: int = maxi(1, int(round(1193182.0 / f)))
			return 1193182.0 / float(divisor)
		ATARI_2600:
			var tia_div: int = clampi(int(round(31440.0 / f)) - 1, 0, 31)
			return 31440.0 / float(tia_div + 1)
		NES:
			if voice == "NES DPCM":
				return f
			if voice == "NES Noise":
				var periods: Array[int] = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
				return _nearest_rate(f, periods, 1789773.0)
			if voice == "NES Triangle":
				var tri_timer: int = clampi(int(round(1789773.0 / (32.0 * f) - 1.0)), 0, 2047)
				return 1789773.0 / (32.0 * float(tri_timer + 1))
			var pulse_timer: int = clampi(int(round(1789773.0 / (16.0 * f) - 1.0)), 8, 2047)
			return 1789773.0 / (16.0 * float(pulse_timer + 1))
		GAME_BOY:
			if voice == "GB Noise":
				return _nearest_gb_noise_rate(f)
			if voice == "GB Wave":
				var wave_x: int = clampi(2048 - int(round(65536.0 / f)), 0, 2047)
				return 65536.0 / float(2048 - wave_x)
			var pulse_x: int = clampi(2048 - int(round(131072.0 / f)), 0, 2047)
			return 131072.0 / float(2048 - pulse_x)
		MASTER_SYSTEM, GENESIS:
			if voice == "PSG Noise":
				var noise_dividers: Array[int] = [512, 1024, 2048]
				return _nearest_rate(f, noise_dividers, 3579545.0)
			if voice.begins_with("PSG"):
				var divider: int = clampi(int(round(3579545.0 / (32.0 * f))), 1, 1023)
				return 3579545.0 / (32.0 * float(divider))
			# Genesis FM voices are not clocked by the SN76489 PSG divider.
			# Keep their requested frequency here; the FM oscillator handles the voice itself.
			return f
		SID:
			var sid_reg: int = clampi(int(round(f * 16777216.0 / 985248.0)), 1, 65535)
			return float(sid_reg) * 985248.0 / 16777216.0
		AY:
			var ay_period: int = clampi(int(round(1773400.0 / (16.0 * f))), 1, 4095)
			return 1773400.0 / (16.0 * float(ay_period))
		POKEY:
			var pokey_div: int = clampi(int(round(1789790.0 / (28.0 * f) - 1.0)), 0, 255)
			return 1789790.0 / (28.0 * float(pokey_div + 1))
		AMIGA:
			var period: int = clampi(int(round(3546895.0 / f)), 124, 65535)
			return 3546895.0 / float(period)
		_:
			return f


static func _nearest_rate(target_hz: float, dividers: Array[int], clock_hz: float) -> float:
	var best_hz: float = clock_hz / float(dividers[0])
	var best_error: float = absf(best_hz - target_hz)
	for divider: int in dividers:
		var rate: float = clock_hz / float(divider)
		var err: float = absf(rate - target_hz)
		if err < best_error:
			best_error = err
			best_hz = rate
	return best_hz


static func _nearest_gb_noise_rate(target_hz: float) -> float:
	var best_hz: float = 524288.0 / 2.0
	var best_error: float = INF
	for shift: int in range(16):
		for divisor_code: int in range(8):
			var divisor: float = 0.5 if divisor_code == 0 else float(divisor_code)
			var rate: float = 524288.0 / divisor / pow(2.0, float(shift + 1))
			var err: float = absf(rate - target_hz)
			if err < best_error:
				best_error = err
				best_hz = rate
	return best_hz
