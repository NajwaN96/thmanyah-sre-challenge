import os
import uuid
import time
from datetime import datetime
from flask import Blueprint, request, jsonify, current_app
from werkzeug.utils import secure_filename
import boto3
from botocore.exceptions import ClientError

images_bp = Blueprint('images', __name__)

# Simulated S3 storage (in production, use real S3 or MinIO)
UPLOAD_FOLDER = '/tmp/images'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

# Create upload directory if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@images_bp.route('/images', methods=['GET'])
def list_images():
    """List all images"""
    try:
        images = []
        for filename in os.listdir(UPLOAD_FOLDER):
            if allowed_file(filename):
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                stat = os.stat(file_path)
                images.append({
                    'id': filename.split('.')[0],
                    'filename': filename,
                    'size': stat.st_size,
                    'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat(),
                    'url': f'/api/images/{filename.split(".")[0]}'
                })
        
        return jsonify({
            'images': images,
            'count': len(images)
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@images_bp.route('/images/<image_id>', methods=['GET'])
def get_image(image_id):
    """Get image metadata by ID"""
    try:
        # Find file with matching ID
        for filename in os.listdir(UPLOAD_FOLDER):
            if filename.startswith(image_id + '.'):
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                if os.path.exists(file_path):
                    stat = os.stat(file_path)
                    return jsonify({
                        'id': image_id,
                        'filename': filename,
                        'size': stat.st_size,
                        'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat(),
                        'url': f'/api/images/{image_id}',
                        'download_url': f'/api/images/{image_id}/download'
                    }), 200
        
        return jsonify({'error': 'Image not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@images_bp.route('/images/<image_id>/download', methods=['GET'])
def download_image(image_id):
    """Download image file"""
    try:
        # Find file with matching ID
        for filename in os.listdir(UPLOAD_FOLDER):
            if filename.startswith(image_id + '.'):
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                if os.path.exists(file_path):
                    from flask import send_file
                    return send_file(file_path, as_attachment=True, download_name=filename)
        
        return jsonify({'error': 'Image not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@images_bp.route('/images', methods=['POST'])
def upload_image():
    """Upload a new image"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if file and allowed_file(file.filename):
            # Generate unique ID
            image_id = str(uuid.uuid4())
            
            # Get file extension
            extension = file.filename.rsplit('.', 1)[1].lower()
            filename = f"{image_id}.{extension}"
            
            # Save file
            file_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(file_path)
            
            # Get file stats
            stat = os.stat(file_path)
            
            return jsonify({
                'id': image_id,
                'filename': filename,
                'size': stat.st_size,
                'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat(),
                'url': f'/api/images/{image_id}',
                'download_url': f'/api/images/{image_id}/download'
            }), 201
        
        return jsonify({'error': 'Invalid file type'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@images_bp.route('/images/<image_id>', methods=['DELETE'])
def delete_image(image_id):
    """Delete an image"""
    try:
        # Find and delete file with matching ID
        for filename in os.listdir(UPLOAD_FOLDER):
            if filename.startswith(image_id + '.'):
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                if os.path.exists(file_path):
                    os.remove(file_path)
                    return jsonify({'message': 'Image deleted successfully'}), 200
        
        return jsonify({'error': 'Image not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@images_bp.route('/images/stats', methods=['GET'])
def get_stats():
    """Get storage statistics"""
    try:
        total_files = 0
        total_size = 0
        
        for filename in os.listdir(UPLOAD_FOLDER):
            if allowed_file(filename):
                file_path = os.path.join(UPLOAD_FOLDER, filename)
                stat = os.stat(file_path)
                total_files += 1
                total_size += stat.st_size
        
        return jsonify({
            'total_files': total_files,
            'total_size_bytes': total_size,
            'total_size_mb': round(total_size / (1024 * 1024), 2),
            'storage_path': UPLOAD_FOLDER
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

