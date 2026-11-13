from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
import wave

root = Path(__file__).resolve().parent
output = Path.cwd() / "outputs"
project = Path("C:/Users/yasmo/Documents/Codex/2026-11-11/hgh/outputs/New Unity Project")
assets = project / "Assets/ElevenEleven/Opening/Media"
rate = 48000
fps = 24
samples_per_frame = rate // fps
rng = random.Random(1111)
tau = math.tau

def ff(*args, capture=False):
    return subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-y", *map(str, args)],
                          check=True, stdout=subprocess.PIPE if capture else None).stdout

def read_stereo(path, length, filters=None):
    args = ["-i", path, "-t", length, "-map", "0:a:0"]
    if filters:
        args += ["-af", filters]
    blob = ff(*args, "-ac", 2, "-ar", rate, "-f", "f32le", "-", capture=True)
    values = array("f")
    values.frombytes(blob)
    return values

def add_event(values, when, length, level, pan, sound):
    offset = round(when * rate)
    end = min(round(length * rate), len(values) // 2 - offset)
    left = math.sqrt((1 - pan) / 2)
    right = math.sqrt((1 + pan) / 2)
    for i in range(max(0, end)):
        t = i / rate
        sample = level * sound(t, length)
        values[2 * (offset + i)] += sample * left
        values[2 * (offset + i) + 1] += sample * right

def env(t, dur, attack=0.01, tail=0.04):
    return min(1, t / attack, (dur - t) / tail)

def tone(hz, t):
    return math.sin(tau * hz * t)

def grit():
    return rng.uniform(-1, 1)

def step(t, dur):
    return env(t, dur, .004, .025) * math.exp(-22 * t) * (.72 * tone(91, t) + .28 * grit())

def knock(t, dur):
    return env(t, dur, .003, .025) * math.exp(-23*t) * (.48*tone(183,t) + .36*tone(329,t) + .16*grit())

def heart(t, dur):
    return env(t, dur, .008, .028) * math.exp(-17*t) * (.79*tone(52,t) + .21*tone(81,t))

def beep(t, dur):
    return env(t, dur, .008, .02) * math.exp(-15*t) * (.87*tone(940,t) + .13*tone(1410,t))

def low_pressure(t, dur):
    return env(t, dur, .60, .35) * (.60*tone(43, t) + .28*tone(56, t) + .12*tone(86,t)) * (.72 + .28*tone(.53,t))

def passage(t, dur):
    return env(t, dur, .75, .65) * (.65*tone(47,t) + .22*tone(74,t) + .13*tone(129,t))

def fracture(t, dur):
    envelope = env(t, dur, .006, .08)
    high = (.42*tone(2845,t) + .21*tone(3790,t) + .19*tone(4825,t) + .18*grit())
    return envelope * (high * math.exp(-11*t) + .3*tone(113,t)*math.exp(-9*t))

def soften(values, gain, seconds):
    for i in range(0, len(values), 2):
        t = i / (2 * rate)
        envelope = min(1, t / .08, max(0, seconds - t) / .16)
        values[i] *= gain * envelope
        values[i + 1] *= gain * envelope

def write_wav(path, values):
    pcm = array("h", (round(max(-.995, min(.995, s)) * 32767) for s in values))
    with wave.open(str(path), "wb") as f:
        f.setparams((2, 2, rate, 0, "NONE", ""))
        f.writeframes(pcm.tobytes())

def mix(name, source, seconds):
    values = array("f", [0]) * (2 * round(seconds * rate))
    flow = read_stereo(source, seconds, "highpass=f=65,acompressor=threshold=0.10:ratio=3.5:attack=4:release=115:knee=2.2")
    limit = min(len(flow), len(values))
    for i in range(limit):
        values[i] = flow[i] * {"friends": 1.8, "lab": 2.05, "trial": 1.75, "threshold": 1.5}[name]
    if name == "friends":
        for i, t in enumerate((.28,.72,1.24,1.76,2.18,2.69,3.14,3.62,4.02,4.43,5.12,5.64,6.19,6.83)):
            add_event(values,t,.17,.075 if t<4.5 else .043,(-.52,.19,.35)[i%3],step)
    elif name == "lab":
        for i, t in enumerate((1.44,1.97,2.44,2.88,3.35,3.82,4.34)):
            add_event(values,t,.17,.11,(-.18,.22)[i%2],step)
        add_event(values,.27,.19,.11,-.6,knock)
        add_event(values,4.94,.23,.16,.55,knock)
        add_event(values,.38,5.4,.045,0,low_pressure)
        add_event(values,5.4,.16,.085,.48,beep)
    elif name == "trial":
        add_event(values,.44,seconds-.69,.13,0,low_pressure)
        t, beat = .49, 0
        while t < seconds - .65:
            power = .083 + .115 * math.sin(math.pi * t / seconds) ** 2
            add_event(values,t,.18,power,0,heart)
            add_event(values,t+.13,.16,power*.66,0,heart)
            if beat % 2 == 0:
                add_event(values,t+.31,.104,.080,.39,beep)
            t += .85 - .36 * math.sin(math.pi * t / seconds) ** 2
            beat += 1
        memory = read_stereo(root / "friends.mp4", 7,
                             "highpass=f=380,lowpass=f=3700,acompressor=threshold=0.09:ratio=3")
        for first, count, src in memories:
            for i in range(count * samples_per_frame):
                s = first * samples_per_frame + i
                m = src * samples_per_frame + i
                window = math.sin(math.pi * i / (count * samples_per_frame)) ** .8
                for ch in range(2):
                    values[2*s+ch] *= 1 - .54 * window
                    values[2*s+ch] += .72 * window * memory[2*m+ch]
    else:
        add_event(values,1.35,3.25,.22,0,passage)
        add_event(values,3.25,1.35,.065,-.22,low_pressure)
        # The display emerges from silence, giving Unity's UI a clean handoff.
        for i in range(round((seconds-.53)*rate), round(seconds*rate)):
            strength = (seconds*rate-i)/(.53*rate)
            for ch in range(2):
                values[2*i+ch] *= strength
    soften(values, 1, seconds)
    return values

trial = root / "trial-final.mp4"
trial_seconds = 8 if trial.exists() else 10
if not trial.exists():
    trial = root / "trial.mp4"
memories = [(76, 10, 29), (128, 13, 57)]
edit = root / "trial-edited.mp4"
cursor = 0
cuts = []
for first, count, source in memories:
    cuts += [(0,cursor,first), (1,source,source+count)]
    cursor = first+count
cuts.append((0,cursor,trial_seconds * fps))
filters = [f"[{input_id}:v]trim=start_frame={first}:end_frame={last},setpts=PTS-STARTPTS[v{i}]"
           for i, (input_id, first, last) in enumerate(cuts)]
filters.append("".join(f"[v{i}]" for i in range(len(cuts)))+f"concat=n={len(cuts)}:v=1:a=0[v]")
video_options = ["-c:v","libx264","-threads","2","-preset","medium","-crf","17","-profile:v","baseline","-level","3.1",
                 "-bf","0","-pix_fmt","yuv420p","-color_primaries","bt709","-color_trc","bt709","-colorspace","bt709"]
ff("-i",trial,"-i",root/"friends.mp4","-filter_complex_threads",2,"-filter_complex",";".join(filters),
   "-map","[v]",*video_options,"-an",edit)

friends_cut = root / "friends-edited.mp4"
ff("-i",root/"friends.mp4","-filter_complex_threads",2,"-filter_complex",
   "[0:v]trim=end_frame=75,setpts=PTS-STARTPTS[v0];[0:v]trim=start_frame=123:end_frame=192,setpts=PTS-STARTPTS[v1];"
   "[0:a]atrim=end=3.125,asetpts=PTS-STARTPTS,afade=t=out:st=2.995:d=0.13[a0];"
   "[0:a]atrim=start=5.125:end=8,asetpts=PTS-STARTPTS,afade=t=in:d=0.13[a1];"
   "[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]",
   "-map","[v]","-map","[a]",*video_options,"-c:a","aac","-b:a","160k",friends_cut)

tracks = {
    "friends": (friends_cut, friends_cut, 6),
    "lab": (root/"lab.mp4", root/"lab.mp4", 6),
    "trial": (edit, trial, trial_seconds),
    "threshold": (root/"threshold.mp4", root/"threshold.mp4", 5),
}
joined_audio = array("f")
for key, (picture, original, duration) in tracks.items():
    track = mix(key, original, duration)
    joined_audio.extend(track)

fracture_audio = array("f",[0])*(2*round(.93*rate))
for i, t in enumerate((.025,.09,.143,.23,.38)):
    add_event(fracture_audio,t,.42,.19/(1+i*.25),(-.3,.52,-.49,.21,0)[i],fracture)
add_event(fracture_audio,.015,.35,.13,0,knock)
write_wav(root/"fracture.wav",fracture_audio)

raw = root/"film-mix.wav"
master = root/"film-master.wav"
write_wav(raw, joined_audio)
ff("-i",raw,"-af","loudnorm=I=-19:LRA=11:TP=-1.7,volume=-1.2dB","-ar",rate,"-c:a","pcm_s16le",master)
start = 0
for name,(picture,_,seconds) in tracks.items():
    options = ["-c:v","copy"] if picture in (edit, friends_cut) else video_options
    ff("-i",picture,"-ss",start,"-i",master,"-t",seconds,"-map","0:v:0","-map","1:a:0",
       *options,"-c:a","aac","-b:a","160k","-movflags","+faststart",root/f"mix-{name}.mp4")
    start += seconds
print(f"Edited {start} seconds; two school memories intercut at frames {[v[0] for v in memories]}.")
