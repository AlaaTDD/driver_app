import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    
    # 1. Replace const AppColors. with AppColors.
    content = content.replace('const AppColors.', 'AppColors.')
    
    # 2. Fix const BoxShadow(...withValues...)
    content = content.replace('const BoxShadow(color: AppColors.black.withValues', 'BoxShadow(color: AppColors.black.withValues')
    content = content.replace('const [BoxShadow(color: AppColors.black.withValues', '[BoxShadow(color: AppColors.black.withValues')
    
    # 3. Fix const TextStyle(...withValues...)
    content = re.sub(r'const\s+TextStyle\(\s*color:\s*AppColors\.[a-zA-Z]+\.withValues', lambda m: m.group(0).replace('const ', ''), content)
    
    # 4. Fix .shadeXXX
    content = re.sub(r'AppColors\.([a-zA-Z]+)\.shade\d+', r'AppColors.\1', content)
    
    # 5. Fix AppColors.primary[300] -> AppColors.white
    content = content.replace('AppColors.primary[300]', 'AppColors.white')
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
