import json
import time

def generate_cast():
    # Width increased to show off dynamic layout
    W = 115
    header = {
        "version": 2,
        "width": W,
        "height": 26,
        "timestamp": int(time.time()),
        "title": "Pacwin v0.2.4 - Responsive Layout Demo"
    }
    
    events = []
    current_time = 0.0
    
    def add_event(text, delay=0.1):
        nonlocal current_time
        current_time += delay
        events.append([round(current_time, 4), "o", text])

    def type_command(cmd):
        add_event("\u001b[1;32mPS C:\\Users\\pacwin>\u001b[0m ", 0.5)
        for char in cmd:
            add_event(char, 0.03)
        add_event("\r\n", 0.2)

    # 1. Clear simulation
    add_event("\u001b[2J\u001b[H", 0.1)

    # 2. Pacwin Search with Responsive Layout
    type_command("pacwin search nvm")
    
    add_event("\r\n\u001b[1;35m  # # #  pacwin v0.2.4  # # #\u001b[0m", 0.1)
    add_event("\r\n  " + ("-" * (W-4)), 0.05)
    add_event("\r\n  > Buscando '\u001b[1;33mnvm\u001b[0m' (Responsive UI Mode)...", 0.1)
    
    add_event("\r\n    [\u001b[32m√\u001b[0m] winget  [\u001b[32m√\u001b[0m] choco   [\u001b[32m√\u001b[0m] scoop\r\n", 0.6)

    # Dynamic Column Widths Calculation (Matching PS logic)
    idxW = 8
    srcW = 12
    remW = W - idxW - srcW - 4
    nameW = int(remW * 0.5)
    idW   = int(remW * 0.3)
    verW  = remW - nameW - idW

    # Header row
    h_row = "\r\n  \u001b[1;30m{0:<5} {1:<" + str(nameW-1) + "} {2:<" + str(idW-1) + "} {3:<" + str(verW-1) + "} {4}\u001b[0m\r\n"
    add_event(h_row.format("#", "Name", "ID", "Version", "Source"), 0.1)
    
    # Separator
    add_event("  \u001b[30m" + ("-" * (W-4)) + "\u001b[0m\r\n", 0.05)
    
    results = [
        ("nvm", "nvm", "1.1.12", "chocolatey"),
        ("nvm-windows", "coreybutler.nvm-windows", "1.1.12", "winget"),
        ("nvm", "nvm", "1.1.12", "scoop"),
        ("nvm-no-install", "nvm-no-install", "1.1.12", "chocolatey"),
        ("nvm.portable", "nvm.portable", "1.1.12", "chocolatey"),
    ]
    
    i = 1
    for name, id, ver, src in results:
        # Format matching the new PS logic
        line = "  \u001b[30m[{0:<2}] \u001b[0m".format(i)
        fmt = "{0:<" + str(nameW) + "}{1:<" + str(idW) + "}{2:<" + str(verW) + "}"
        line += fmt.format(name, id, ver)
        
        # Source color simulation
        src_col = "\u001b[32m" # default green for choco/winget/scoop
        line += src_col + src + "\u001b[0m\r\n"
        
        add_event(line, 0.08)
        i += 1

    add_event("\r\n\u001b[1;32m  [TIP]\u001b[0m La lista ahora se adapta a tu terminal.\r\n", 0.3)
    add_event("\r\n\u001b[1;32mPS C:\\Users\\pacwin>\u001b[0m ", 0.5)

    with open("g:/DEVELOPMENT/pacwin/demo.cast", "w", encoding="utf-8") as f:
        f.write(json.dumps(header) + "\n")
        for e in events:
            f.write(json.dumps(e) + "\n")

if __name__ == "__main__":
    generate_cast()
