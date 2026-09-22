
import sys

def check_braces(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    stack = []
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for char in line:
            if char == '{':
                stack.append(('{', i + 1))
            elif char == '}':
                if not stack:
                    print(f"Extra closing brace at line {i + 1}")
                    return
                stack.pop()
    
    if stack:
        for b, line in stack:
            print(f"Unmatched opening brace at line {line}")
    else:
        print("No brace errors found")

if __name__ == "__main__":
    check_braces(sys.argv[1])
