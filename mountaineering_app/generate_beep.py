import math
import wave
import struct
import base64

sample_rate = 44100
duration = 0.5 # seconds
frequency = 2500.0 # high pitch beep

obj = wave.open('beep.wav','w')
obj.setnchannels(1) # mono
obj.setsampwidth(2)
obj.setframerate(sample_rate)

for i in range(int(duration * sample_rate)):
    value = int(32767.0 * math.sin(frequency * math.pi * 2.0 * i / sample_rate))
    data = struct.pack('<h', value)
    obj.writeframesraw(data)

obj.close()

with open('beep.wav', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode('utf-8')
    print(b64)
