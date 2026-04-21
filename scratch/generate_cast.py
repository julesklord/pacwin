import json
import time

def generate_cast():
    header = {
        "version": 2,
        "width": 100,
        "height": 30,
        "timestamp": int(time.time()),
        "title": "Pacwin Demo v0.2.4"
    }
    
    events = []
    current_time = 0.0
    
    def add_event(text, delay=0.1):
        nonlocal current_time
        current_time += delay
        events.append([round(current_time, 4), "o", text])

    # Simulation: Typing the command
    add_event("\u001b[32mPS C:\\Users\\julio\\pacwin>\u001b[0m ", 0.5)
    command = "pacwin search vlc"
    for char in command:
        add_event(char, 0.05)
    add_event("\r\n", 0.3)

    # Simulation: Header output
    add_event("\r\n\u001b[1;36m  >> pacwin v0.2.4  --  universal package layer\u001b[0m", 0.2)
    add_event("\r\n\u001b[1;34m  [ winget + | choco + | scoop + ]\u001b[0m", 0.05)
    add_event("\r\n  ================================================", 0.05)
    add_event("\r\n  > Searching for 'vlc'...", 0.2)
    
    # Simulation: Spinner/Progress
    add_event("\r\n    [\u001b[32m√\u001b[0m] winget ", 0.8)
    add_event(" [\u001b[32m√\u001b[0m] choco ", 0.5)
    add_event(" [\u001b[33m-\u001b[0m] scoop ", 0.3)
    add_event("\r\n", 0.1)

    # Simulation: Table
    table_header = """
  #    Name                                 ID                       Version        Source
  --------------------------------------------------------------------
"""
    add_event(table_header, 0.3)
    
    results = [
        "[1 ] VLC                                 XPDM1ZW6815MQM          Unknown       winget",
        "[2 ] VLC media player                    VideoLAN.VLC            3.0.23     .  winget",
        "[3 ] vlc                                 vlc                     3.0.23        chocolatey",
        "[4 ] vlc.install                         vlc.install             3.0.23        chocolatey"
    ]
    
    for res in results:
        add_event("  " + res + "\r\n", 0.1)

    add_event("\r\n\u001b[32mPS C:\\Users\\julio\\pacwin>\u001b[0m ", 0.5)

    with open("g:/DEVELOPMENT/pacwin/demo.cast", "w", encoding="utf-8") as f:
        f.write(json.dumps(header) + "\n")
        for e in events:
            f.write(json.dumps(e) + "\n")

if __name__ == "__main__":
    generate_cast()
