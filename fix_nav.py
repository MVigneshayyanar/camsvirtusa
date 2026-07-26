import os
import re

dir_path = r'c:\camsvirtusa\lib'
for root, dirs, files in os.walk(dir_path):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            needs_update = False
            if 'PhosphorIconsRegular.magnifyingGlass' in content or '_goToSearch' in content:
                needs_update = True
            
            if not needs_update:
                continue

            # Need to make sure import '../Shared/newsScreen.dart'; is added
            if 'package:camsvirtusa/Shared/newsScreen.dart' not in content:
                content = "import 'package:camsvirtusa/Shared/newsScreen.dart';\n" + content

            # Replace the magnifying glass
            content = content.replace('PhosphorIconsRegular.magnifyingGlass', 'PhosphorIconsRegular.newspaper')
            
            # Replace the function
            content = content.replace('void _goToSearch() {', 'void _goToNews() {')
            content = content.replace('_goToSearch', '_goToNews')

            # Special case for studentDashboard
            if 'assets/search.png' in content:
                content = re.sub(r'/\*[\s\S]*?search\.png[\s\S]*?\*/', r'''IconButton(
              icon: Icon(
                PhosphorIconsRegular.newspaper,
                size: screenWidth > 600 ? 30 : 26,
                color: Colors.black87,
              ),
              onPressed: _goToNews,
            ),''', content)
            
            # Replace _goToNews body completely using regex
            content = re.sub(r'void _goToNews\(\)\s*\{[\s\S]*?\}', r'''void _goToNews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }''', content)

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {filepath}")
