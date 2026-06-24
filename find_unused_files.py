import os
import glob
import re

def main():
    lib_dir = 'lib'
    all_dart_files = glob.glob(os.path.join(lib_dir, '**', '*.dart'), recursive=True)
    
    file_contents = {}
    for f in all_dart_files:
        with open(f, 'r', encoding='utf-8', errors='ignore') as file:
            file_contents[f] = file.read()
            
    unused_files = []
    for f in all_dart_files:
        if f.endswith('main.dart'):
            continue
            
        # Get the filename and the package path
        basename = os.path.basename(f)
        
        # We look for the basename in all other files
        # It's a heuristic, but if the basename is never mentioned, it's 100% unused.
        is_used = False
        for other_f, content in file_contents.items():
            if f == other_f:
                continue
            if basename in content:
                is_used = True
                break
                
        if not is_used:
            unused_files.append(f)
            
    print("Potentially Unused Dart Files:")
    for f in unused_files:
        print(f)

if __name__ == '__main__':
    main()
