import os
os.system("py -3.10 -m pip install watchdog")
import time, datetime
import subprocess
import concurrent.futures
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

last = [0]
class Watcher:
    DIRECTORY_TO_WATCH = os.getcwd()

    def __init__(self):
        self.observer = Observer()

    def run(self):
        event_handler = Handler()
        self.observer.schedule(event_handler, self.DIRECTORY_TO_WATCH, recursive=True)
        self.observer.start()
        try:
            while True:
                time.sleep(5)
        except:
            self.observer.stop()
            print("Observer Stopped")

        self.observer.join()

def run_command(command):
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return "\t" + result.stdout + result.stderr

class Handler(FileSystemEventHandler):
    @staticmethod
    def on_modified(event):
        global last
        if event.is_directory or event.src_path.startswith(os.getcwd() + "\\.git"):
            return None
        elif time.time () - last[0] > 1:
            
            # Commande à exécuter lors de la modification du fichier
            os.system('cls')
            print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
            os.system('mdok lua54 build.lua')

            tasks = []
            with concurrent.futures.ThreadPoolExecutor() as executor:
                for name, optn in [("Dev", ""), ("Dist", " dist")]:
                    tasks.append(executor.submit(lambda x: x+"\n", name))
                    for version in ["jit", "51", "54"]:
                        command = f'mdok lua{version} test/test.lua{optn}'
                        # On ajoute chaque futur à la liste des tâches
                        tasks.append(executor.submit(run_command, command))

                for task in tasks:
                    output = task.result()  # Attendre que la tâche soit terminée et récupérer le résultat
                    print(output, end="")

            last = [time.time()]

if __name__ == '__main__':
    w = Watcher()
    w.run()
