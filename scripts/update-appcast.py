#!/usr/bin/env python3
"""Update or create appcast.xml with a new release entry."""
import argparse
import re
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)

def sparkle(tag):
    return f"{{{SPARKLE_NS}}}{tag}"

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("appcast", help="Path to appcast.xml")
    p.add_argument("--version", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--size", required=True, type=int)
    p.add_argument("--signature", required=True)
    p.add_argument("--pubdate", required=True)
    p.add_argument("--min-os", default="13.3")
    return p.parse_args()

def build_item(args):
    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Version {args.version}"
    ET.SubElement(item, "pubDate").text = args.pubdate
    ET.SubElement(item, sparkle("version")).text = args.version.replace(".", "")[-4:] or "1"
    ET.SubElement(item, sparkle("shortVersionString")).text = args.version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = args.min_os
    enc = ET.SubElement(item, "enclosure")
    enc.set("url", args.url)
    enc.set("length", str(args.size))
    enc.set("type", "application/octet-stream")
    enc.set(sparkle("edSignature"), args.signature)
    return item

def main():
    args = parse_args()
    path = Path(args.appcast)

    if path.exists():
        tree = ET.parse(path)
        root = tree.getroot()
        channel = root.find("channel")
    else:
        root = ET.Element("rss", version="2.0")
        root.set("xmlns:sparkle", SPARKLE_NS)
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "DNSFlip"
        ET.SubElement(channel, "link").text = "https://github.com/cicoub13/DNSFlip"
        ET.SubElement(channel, "description").text = "DNSFlip updates"
        tree = ET.ElementTree(root)

    # Remove existing entry with same version
    for existing in channel.findall("item"):
        sv = existing.find(sparkle("shortVersionString"))
        if sv is not None and sv.text == args.version:
            channel.remove(existing)

    # Prepend new entry (after title/link/description)
    insert_pos = sum(1 for _ in channel.findall("title")) + \
                 sum(1 for _ in channel.findall("link")) + \
                 sum(1 for _ in channel.findall("description"))
    channel.insert(insert_pos, build_item(args))

    ET.indent(tree, space="  ")
    tree.write(path, encoding="unicode", xml_declaration=True)
    print(f"Updated {path} with v{args.version}")

if __name__ == "__main__":
    main()
