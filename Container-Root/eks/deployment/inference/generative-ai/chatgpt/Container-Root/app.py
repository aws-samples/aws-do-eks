import gradio as gr
import openai
import requests
import csv


prompt_templates = {"Default ChatGPT": ""}

def get_empty_state():
    return {"total_tokens": 0, "messages": []}

def download_prompt_templates():
    url = "https://raw.githubusercontent.com/f/awesome-chatgpt-prompts/main/prompts.csv"
    try:
        response = requests.get(url)
        reader = csv.reader(response.text.splitlines())
        next(reader)  # skip the header row
        for row in reader:
            if len(row) >= 2:
                act = row[0].strip('"')
                prompt = row[1].strip('"')
                prompt_templates[act] = prompt

    except requests.exceptions.RequestException as e:
        print(f"An error occurred while downloading prompt templates: {e}")
        return

    choices = list(prompt_templates.keys())
    choices = choices[:1] + sorted(choices[1:])
    return gr.update(value=choices[0], choices=choices)

def on_token_change(user_token):
    openai.api_key = user_token

def on_prompt_template_change(prompt_template):
    if not isinstance(prompt_template, str): return
    return prompt_templates[prompt_template]

def submit_message(user_token, prompt, prompt_template, temperature, max_tokens, context_length, state):

    history = state['messages']

    if not prompt:
        return gr.update(value=''), [(history[i]['content'], history[i+1]['content']) for i in range(0, len(history)-1, 2)], f"Total tokens used: {state['total_tokens']}", state
    
    prompt_template = prompt_templates[prompt_template]

    system_prompt = []
    if prompt_template:
        system_prompt = [{ "role": "system", "content": prompt_template }]

    prompt_msg = { "role": "user", "content": prompt }

    if not user_token:
        history.append(prompt_msg)
        history.append({
            "role": "system",
            "content": "Error: OpenAI API Key is not set."
        })
        return '', [(history[i]['content'], history[i+1]['content']) for i in range(0, len(history)-1, 2)], f"Total tokens used: 0", state
    
    try:
        completion = openai.ChatCompletion.create(model="gpt-3.5-turbo", messages=system_prompt + history[-context_length*2:] + [prompt_msg], temperature=temperature, max_tokens=max_tokens)

        history.append(prompt_msg)
        history.append(completion.choices[0].message.to_dict())

        state['total_tokens'] += completion['usage']['total_tokens']
    
    except Exception as e:
        history.append(prompt_msg)
        history.append({
            "role": "system",
            "content": f"Error: {e}"
        })

    total_tokens_used_msg = f"Total tokens used: {state['total_tokens']}"
    chat_messages = [(history[i]['content'], history[i+1]['content']) for i in range(0, len(history)-1, 2)]

    return '', chat_messages, total_tokens_used_msg, state

def clear_conversation():
    return gr.update(value=None, visible=True), None, "", get_empty_state()


css = """
      #col-container {max-width: 80%; margin-left: auto; margin-right: auto;}
      #chatbox {min-height: 400px;}
      #header {text-align: center;}
      #prompt_template_preview {padding: 1em; border-width: 1px; border-style: solid; border-color: #e0e0e0; border-radius: 4px;}
      #total_tokens_str {text-align: right; font-size: 0.8em; color: #666;}
      #label {font-size: 0.8em; padding: 0.5em; margin: 0;}
      .message { font-size: 1.2em; }
      """

with gr.Blocks(css=css) as demo:
    
    state = gr.State(get_empty_state())


    with gr.Column(elem_id="col-container"):
        gr.Markdown("""## OpenAI ChatGPT Demo
                    Using the ofiicial API (gpt-3.5-turbo model)
                    Prompt templates from [awesome-chatgpt-prompts](https://github.com/f/awesome-chatgpt-prompts).""",
                    elem_id="header")

        with gr.Row():
            with gr.Column():
                chatbot = gr.Chatbot(elem_id="chatbox")
                input_message = gr.Textbox(show_label=False, placeholder="Enter text and press enter", visible=True).style(container=False)
                btn_submit = gr.Button("Submit")
                total_tokens_str = gr.Markdown(elem_id="total_tokens_str")
                btn_clear_conversation = gr.Button("🔃 Start New Conversation")
            with gr.Column():
                gr.Markdown("Enter your OpenAI API Key. You can get one [here](https://platform.openai.com/account/api-keys).", elem_id="label")
                user_token = gr.Textbox(value='', placeholder="OpenAI API Key", type="password", show_label=False)
                prompt_template = gr.Dropdown(label="Set a custom insruction for the chatbot:", choices=list(prompt_templates.keys()))
                prompt_template_preview = gr.Markdown(elem_id="prompt_template_preview")
                with gr.Accordion("Advanced parameters", open=False):
                    temperature = gr.Slider(minimum=0, maximum=2.0, value=0.7, step=0.1, label="Temperature", info="Higher = more creative/chaotic")
                    max_tokens = gr.Slider(minimum=100, maximum=4096, value=1000, step=1, label="Max tokens per response")
                    context_length = gr.Slider(minimum=1, maximum=10, value=2, step=1, label="Context length", info="Number of previous messages to send to the chatbot. Be careful with high values, it can blow up the token budget quickly.")

    gr.HTML('''<p><br><br><br><center>This demo is inspired by:<a href="https://huggingface.co/spaces/anzorq/chatgpt-demo">https://huggingface.co/spaces/anzorq/chatgpt-demo</a></p></center>''')

    btn_submit.click(submit_message, [user_token, input_message, prompt_template, temperature, max_tokens, context_length, state], [input_message, chatbot, total_tokens_str, state])
    input_message.submit(submit_message, [user_token, input_message, prompt_template, temperature, max_tokens, context_length, state], [input_message, chatbot, total_tokens_str, state])
    btn_clear_conversation.click(clear_conversation, [], [input_message, chatbot, total_tokens_str, state])
    prompt_template.change(on_prompt_template_change, inputs=[prompt_template], outputs=[prompt_template_preview])
    user_token.change(on_token_change, inputs=[user_token], outputs=[])

    
    demo.load(download_prompt_templates, inputs=None, outputs=[prompt_template], queur=False)


demo.queue(concurrency_count=10)
demo.launch(height='800px')
