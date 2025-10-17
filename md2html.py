#!/usr/bin/env python3
"""
Markdown to HTML Converter

This script converts Markdown files to HTML using the markdown library.
Supports basic Markdown syntax and common extensions.
"""

import markdown
import argparse
import sys
from pathlib import Path


def convert_markdown_to_html(markdown_text, extensions=None):
    """
    Convert markdown text to HTML.
    
    Args:
        markdown_text (str): The markdown content to convert
        extensions (list): List of markdown extensions to use
    
    Returns:
        str: HTML content
    """
    if extensions is None:
        extensions = ['extra', 'codehilite', 'toc']
    
    md = markdown.Markdown(extensions=extensions)
    return md.convert(markdown_text)


def read_file(file_path):
    """Read content from a file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            return file.read()
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)


def write_file(content, output_path):
    """Write content to a file."""
    try:
        with open(output_path, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"HTML file saved to: {output_path}")
    except Exception as e:
        print(f"Error writing file: {e}")
        sys.exit(1)


def create_full_html_document(html_content, title="Converted Document"):
    """
    Wrap HTML content in a complete HTML document structure.
    
    Args:
        html_content (str): The converted HTML content
        title (str): Title for the HTML document
    
    Returns:
        str: Complete HTML document
    """
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }}
        code {{
            background-color: #f4f4f4;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }}
        pre {{
            background-color: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }}
        blockquote {{
            border-left: 4px solid #ddd;
            margin: 0;
            padding-left: 20px;
            color: #666;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background-color: #f2f2f2;
        }}
    </style>
</head>
<body>
{html_content}
</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(
        description="Convert Markdown files to HTML",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python md_to_html.py input.md                    # Convert to input.html
  python md_to_html.py input.md -o output.html     # Specify output file
  python md_to_html.py input.md --fragment         # Output HTML fragment only
  echo "# Hello" | python md_to_html.py --stdin    # Read from stdin
        """
    )
    
    parser.add_argument('input_file', nargs='?', help='Input Markdown file')
    parser.add_argument('-o', '--output', help='Output HTML file')
    parser.add_argument('--stdin', action='store_true', help='Read from stdin')
    parser.add_argument('--fragment', action='store_true', 
                       help='Output HTML fragment only (no full document structure)')
    parser.add_argument('--title', default='Converted Document', 
                       help='Title for the HTML document (default: "Converted Document")')
    
    args = parser.parse_args()
    
    # Read input
    if args.stdin:
        markdown_content = sys.stdin.read()
        input_name = "stdin"
    elif args.input_file:
        markdown_content = read_file(args.input_file)
        input_name = Path(args.input_file).stem
    else:
        parser.print_help()
        sys.exit(1)
    
    # Convert markdown to HTML
    html_content = convert_markdown_to_html(markdown_content)
    
    # Create full document or fragment
    if args.fragment:
        output_content = html_content
    else:
        title = args.title if args.title != 'Converted Document' else input_name
        output_content = create_full_html_document(html_content, title)
    
    # Output
    if args.output:
        write_file(output_content, args.output)
    elif args.input_file and not args.stdin:
        output_path = Path(args.input_file).with_suffix('.html')
        write_file(output_content, output_path)
    else:
        print(output_content)


if __name__ == "__main__":
    main()
