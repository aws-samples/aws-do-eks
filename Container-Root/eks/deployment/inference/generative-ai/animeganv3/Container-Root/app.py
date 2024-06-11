import os
import cv2
import gradio as gr
import AnimeGANv3_src


os.makedirs('output', exist_ok=True)


def inference(img_path, Style, if_face=None):
    print(img_path, Style, if_face)
    try:
        img = cv2.imread(img_path)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        if Style == "AnimeGANv3_Arcane":
            f = "A"
        elif Style == "AnimeGANv3_Trump v1.0":
            f = "T"
        elif Style == "AnimeGANv3_Shinkai":
            f = "S"
        elif Style == "AnimeGANv3_PortraitSketch":
            f = "P"
        elif Style == "AnimeGANv3_Hayao":
            f = "H"
        elif Style == "AnimeGANv3_Disney v1.0":
            f = "D"
        elif Style == "AnimeGANv3_JP_face v1.0":
            f = "J"
        else:
            f = "U"

        try:
            det_face = True if if_face=="Yes" else False
            output = AnimeGANv3_src.Convert(img, f, det_face)
            save_path = f"output/out.{img_path.rsplit('.')[-1]}"
            cv2.imwrite(save_path, output[:, :, ::-1])
            return output, save_path
        except RuntimeError as error:
            print('Error', error)
    except Exception as error:
        print('global exception', error)
        return None, None


title = "AnimeGANv3: Produce your own animation."
description = r"""
To use this demo, simply upload your image, select the animation style, then click <b>Subimt</b> to generate an animated image. 😊

"""
article = r"""

----------

## License  
Please refer to <a href='https://github.com/TachibanaYoshino/AnimeGANv3#license' target='_blank'>AnimeGANv3</a> for LICENSE information.

## Acknowledgements 
* This demo is based on <a href='https://github.com/TachibanaYoshino/AnimeGANv3' target='_blank'>AnimeGANv3 GitHub repo</a> and 
<a href='https://huggingface.co/spaces/TachibanaYoshino/AnimeGANv3' target='_blank'>AnimeGANv3 HuggingFace grad.io app</a><br> with author Xin Chen
* The Huggingface UI is referenced from @akhaliq/GFPGAN.     
* The dataset of AnimeGANv3_JP_face v1.0 is from DCTnet and then manually optimized
* This demo is also inspired by <a href='https://differentdimensionme.net/#demo' target='_blank'>Different Dimension Me</a>

"""
gr.Interface(
    inference, [
        gr.Image(type="filepath", label="Input"),
        gr.Dropdown([
            'AnimeGANv3_Hayao',
            'AnimeGANv3_Shinkai',
            'AnimeGANv3_Arcane',
            'AnimeGANv3_USA',
            'AnimeGANv3_Trump v1.0',
            'AnimeGANv3_Disney v1.0',
            'AnimeGANv3_PortraitSketch',
            'AnimeGANv3_JP_face v1.0',
        ], 
            type="value",
            value='AnimeGANv3_Hayao',
            label='AnimeGANv3 Style'),
        gr.Radio(['Yes', 'No'], type="value", value='No', label='Extract face'),
    ], [
        gr.Image(type="numpy", label="Output (The whole image)"),
        gr.File(label="Download the output image")
    ],
    title=title,
    description=description,
    article=article,
    allow_flagging="never"
   ).launch()

#  examples=[[]]
    #examples=[['samples/7_out.jpg', 'AnimeGANv3_Arcane', "Yes"], ['samples/15566.jpg', 'AnimeGANv3_USA', "Yes"],['samples/23034.jpg', 'AnimeGANv3_Trump v1.0', "Yes"], ['samples/jp_13.jpg', 'AnimeGANv3_Hayao', "No"],
    #          ['samples/jp_20.jpg', 'AnimeGANv3_Shinkai', "No"], ['samples/Hamabe Minami.jpg', 'AnimeGANv3_Disney v1.0', "Yes"], ['samples/120.jpg', 'AnimeGANv3_JP_face v1.0', "Yes"], ['samples/52014.jpg', 'AnimeGANv3_PortraitSketch', "Yes"]]).launch(enable_queue=True)
