from PIL import Image
import torch
import gradio as gr

processor="cpu"
if torch.cuda.is_available():
    processor="cuda"

model2 = torch.hub.load(
    "AK391/animegan2-pytorch:main",
    "generator",
    pretrained=True,
    device=processor,
    progress=False
)


model1 = torch.hub.load("AK391/animegan2-pytorch:main", "generator", pretrained="face_paint_512_v1",  device=processor)
face2paint = torch.hub.load(
    'AK391/animegan2-pytorch:main', 'face2paint', 
    size=512, device=processor,side_by_side=False
)
def inference(img, ver):
    if ver == 'version 2 (🔺 robustness,🔻 stylization)':
        out = face2paint(model2, img)
    else:
        out = face2paint(model1, img)
    return out
  
title = "AnimeGANv2: Create your own anime character " 
description = "Upload an image and click <b>Submit</b>. For best results, please use a cropped portrait picture."
article = """

------------

## Acknowledgements

This demo is inspired by:

* Github repo: <a href='https://github.com/bryandlee/animegan2-pytorch' target='_blank'>animaegan2-pytorch</a>
* HugginFace space: <a href='https://huggingface.co/spaces/akhaliq/AnimeGANv2' target='_blank'>AnimeGANv2</a>

"""

gr.Interface(inference, [gr.Image(type="pil"),gr.Radio(['version 1 (🔺 stylization, 🔻 robustness)','version 2 (🔺 robustness,🔻 stylization)'], type="value", value='version 2 (🔺 robustness,🔻 stylization)', label='version')
], gr.Image(type="pil"),title=title,description=description,article=article,allow_flagging='auto').launch()

