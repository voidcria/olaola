# zoom suave: zm.py PAG x0,y0,x1,y1 [escala] -> view/z.png
import sys
from PIL import Image, ImageOps
B='/tmp/claude-0/-home-user-olaola/506d9357-0233-5e61-ba9a-2093b0ac2642/scratchpad/'
p=int(sys.argv[1]); x0,y0,x1,y1=map(int,sys.argv[2].split(',')); s=float(sys.argv[3]) if len(sys.argv)>3 else 3
im=Image.open(B+'orig/p-%03d.png'%p).convert('L').crop((x0,y0,x1,y1))
im=im.resize((int(im.width*s),int(im.height*s)),Image.LANCZOS)
im=ImageOps.autocontrast(im,cutoff=(2,0.3)).point(lambda v:int(255*(v/255)**1.25))
im.save(B+'view/z.png')
