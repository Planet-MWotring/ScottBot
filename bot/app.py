from flask import Flask, request, render_template, send_file, jsonify, url_for
import os
from werkzeug.utils import secure_filename
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import azure.cognitiveservices.speech as speechsdk
from docx import Document
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

app = Flask(__name__, template_folder='../templates', static_folder='../static')
app.config['UPLOAD_FOLDER'] = '../uploads'
app.config['DOWNLOAD_FOLDER'] = '../downloads'
app.config['ALLOWED_EXTENSIONS'] = {'mp3'}

# Initialize Azure clients
credential = DefaultAzureCredential()
blob_service_client = BlobServiceClient(account_url=os.getenv('AZURE_STORAGE_ACCOUNT_URL'), credential=credential)
key_vault_client = SecretClient(vault_url=os.getenv('AZURE_KEY_VAULT_URL'), credential=credential)
speech_key = key_vault_client.get_secret('AzureSpeechServiceKey').value

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def transcribe_audio(file_path):
    speech_config = speechsdk.SpeechConfig(subscription=speech_key, region=os.getenv('AZURE_SPEECH_REGION'))
    audio_config = speechsdk.audio.AudioConfig(filename=file_path)
    recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config)
    result = recognizer.recognize_once()
    return result.text if result.reason == speechsdk.ResultReason.RecognizedSpeech else None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return 'No file part'
    file = request.files['file']
    if file.filename == '':
        return 'No selected file'
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)
        return 'File uploaded successfully'
    return 'Invalid file type'

@app.route('/transcribe', methods=['POST'])
def transcribe_file():
    data = request.get_json()
    filename = data.get('filename')
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    if not os.path.exists(file_path):
        return jsonify(success=False, message='File not found')

    transcription = transcribe_audio(file_path)
    if transcription:
        doc = Document()
        doc.add_paragraph(transcription)
        transcription_path = os.path.join(app.config['DOWNLOAD_FOLDER'], 'transcription.docx')
        doc.save(transcription_path)
        return jsonify(success=True, filename='transcription.docx')
    return jsonify(success=False, message='Transcription failed')

@app.route('/download/<filename>')
def download_file(filename):
    return send_file(os.path.join(app.config['DOWNLOAD_FOLDER'], filename), as_attachment=True)

if __name__ == '__main__':
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['DOWNLOAD_FOLDER'], exist_ok=True)
    app.run(debug=True)