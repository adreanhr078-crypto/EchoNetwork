import json, math
src=r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\rokoko-idle-source\unpacked\idle_loop_scan.json'
rows=json.load(open(src))
def dist(a,b):
    return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
for r in rows:
    samples=r['samples']; names=r['names']; d={n:i*3 for i,n in enumerate(names)}
    best=(1e10,None,None,None,None)
    for i in range(10,len(samples)-61):
        for j in range(i+20,min(i+61,len(samples)-8)):
            p=dist(samples[i]['v'],samples[j]['v'])
            vel=dist([x-y for x,y in zip(samples[i+1]['v'],samples[i-1]['v'])],[x-y for x,y in zip(samples[j+1]['v'],samples[j-1]['v'])])
            score=p+1.5*vel
            if score<best[0]:best=(score,samples[i]['f'],samples[j]['f'],p,vel)
    hands=[]
    feet=[]
    heads=[]
    for s in samples[10:-8]:
        v=s['v']; hands.append(v[d['LeftHand']:d['LeftHand']+3]+v[d['RightHand']:d['RightHand']+3]); feet.append(v[d['LeftFoot']:d['LeftFoot']+3]+v[d['RightFoot']:d['RightFoot']+3]); heads.append(v[d['Head']:d['Head']+3])
    def spread(arr): return round(max(dist(a,b) for a in arr[::10] for b in arr[::10]),3)
    print(r['name'],'best',best,'hand_spread',spread(hands),'foot_spread',spread(feet),'head_spread',spread(heads))
    for f in [1,31,91,181,301,601,int(samples[-1]['f'])]:
        s=min(samples,key=lambda s:abs(s['f']-f))
        v=s['v']
        print('  f',s['f'],'head',v[d['Head']:d['Head']+3], 'LH',v[d['LeftHand']:d['LeftHand']+3], 'RH',v[d['RightHand']:d['RightHand']+3], 'LF',v[d['LeftFoot']:d['LeftFoot']+3], 'RF',v[d['RightFoot']:d['RightFoot']+3])
