from pathlib import Path
import numpy as np
from PIL import Image

root=Path("Assets/ElevenEleven/Opening/Stormworks/Observatory")
rng=np.random.default_rng(110815)
n=1024
def octave(size):
    field=rng.random((size,size), dtype=np.float32)
    padded=np.pad(field,((2,2),(2,2)),mode="wrap")
    grown=Image.fromarray(padded).resize((n+(4*n)//size,)*2,Image.Resampling.BICUBIC)
    offset=2*n//size
    return np.asarray(grown)[offset:offset+n,offset:offset+n]
wide=octave(8)
coarse=octave(32)
chip=octave(128)
grain=octave(512)
y,x=np.indices((n,n),dtype=np.float32)/n
vein=(.5+.5*np.cos(2*np.pi*(14*y+2*x+wide*.6)))**11
matrix=.45*wide+.30*coarse+.17*chip+.08*grain
rind=np.clip(.46*matrix+.31*vein,0,1)
albedo=np.clip(np.array([44,47,53])[None,None,:]+matrix[:,:,None]*np.array([61,64,69])+rind[:,:,None]*np.array([31,20,9]),0,255)
Image.fromarray(albedo.astype("uint8")).save(root/"Basalt strata.png")
height=.45*wide+.23*coarse+.07*chip+.019*grain-.09*vein
dx=(np.roll(height,1,axis=1)-np.roll(height,-1,axis=1))*7.5
dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*7.5
nz=np.ones_like(dx)
normal=np.stack([dx,dy,nz],axis=2)
normal/=np.linalg.norm(normal,axis=2,keepdims=True)
Image.fromarray(((normal*.5+.5)*255).astype("uint8")).save(root/"Basalt tangent normal.png")
