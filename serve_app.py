#!/usr/bin/env python3
import os
import sys
import mimetypes
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class WorkoutHTTPHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def translate_path(self, path):
        clean = path.split('?')[0].rstrip('/')
        if clean in ('/download', '/apk', '/install'):
            path = '/download.html'
        return super().translate_path(path)

    def do_HEAD(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path == '/workout.apk':
            apk_path = os.path.join(DIRECTORY, 'workout.apk')
            if os.path.isfile(apk_path):
                self.send_response(200)
                self.send_header('Content-Type', 'application/vnd.android.package-archive')
                self.send_header('Content-Disposition', 'attachment; filename="workout.apk"')
                self.send_header('Content-Length', str(os.path.getsize(apk_path)))
                self.send_header('Accept-Ranges', 'bytes')
                self.end_headers()
                return
        return super().do_HEAD()

    def do_GET(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path in ('/download', '/apk', '/install'):
            self.path = '/download.html'
            return super().do_GET()

        if clean_path == '/workout.apk':
            apk_path = os.path.join(DIRECTORY, 'workout.apk')
            if not os.path.isfile(apk_path):
                self.send_error(404, "workout.apk not found")
                return

            file_size = os.path.getsize(apk_path)
            range_header = self.headers.get('Range')

            if range_header and range_header.startswith('bytes='):
                try:
                    ranges = range_header[6:].split('-')
                    start = int(ranges[0]) if ranges[0] else 0
                    end = int(ranges[1]) if ranges[1] else file_size - 1
                    end = min(end, file_size - 1)
                    content_length = end - start + 1

                    self.send_response(206)
                    self.send_header('Content-Type', 'application/vnd.android.package-archive')
                    self.send_header('Content-Disposition', 'attachment; filename="workout.apk"')
                    self.send_header('Content-Range', f'bytes {start}-{end}/{file_size}')
                    self.send_header('Content-Length', str(content_length))
                    self.send_header('Accept-Ranges', 'bytes')
                    self.end_headers()

                    with open(apk_path, 'rb') as f:
                        f.seek(start)
                        remaining = content_length
                        chunk_size = 64 * 1024
                        while remaining > 0:
                            chunk = f.read(min(chunk_size, remaining))
                            if not chunk:
                                break
                            self.wfile.write(chunk)
                            remaining -= len(chunk)
                    return
                except (ConnectionResetError, BrokenPipeError):
                    return
                except Exception as e:
                    sys.stderr.write(f"Range handling error: {e}\n")

            # Standard full download
            try:
                self.send_response(200)
                self.send_header('Content-Type', 'application/vnd.android.package-archive')
                self.send_header('Content-Disposition', 'attachment; filename="workout.apk"')
                self.send_header('Content-Length', str(file_size))
                self.send_header('Accept-Ranges', 'bytes')
                self.end_headers()

                with open(apk_path, 'rb') as f:
                    chunk_size = 64 * 1024
                    while True:
                        chunk = f.read(chunk_size)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                return
            except (ConnectionResetError, BrokenPipeError):
                return
            except Exception as e:
                sys.stderr.write(f"Download error: {e}\n")
                return

        return super().do_GET()

def run(port=8088):
    mimetypes.add_type('application/vnd.android.package-archive', '.apk')
    mimetypes.add_type('application/javascript', '.js')
    mimetypes.add_type('application/wasm', '.wasm')
    
    server_address = ('0.0.0.0', port)
    httpd = ThreadingHTTPServer(server_address, WorkoutHTTPHandler)
    print(f"Workout Web Server running on http://0.0.0.0:{port}/ (serving {DIRECTORY})", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
    run(port)
