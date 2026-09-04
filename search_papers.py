import urllib.request
import urllib.parse
import json
import time

papers = [
    "Gaussian Splatting Underwater: A Controlled Cross-Regime Study",
    "WaterClear-GS",
    "AquaSplatting",
    "RUSplatting",
    "Water-Adapted 3DGS",
    "UW-3DGS",
    "DualPhys-GS",
    "Gaussian Splashing",
    "SeaSplat",
    "WaterGS",
    "UW-GS",
    "Underwater360",
    "R-Splatting",
    "Spatiotemporal Degradation-Aware 3DGS"
]

def search_arxiv(title):
    url = f"http://export.arxiv.org/api/query?search_query=ti:%22{urllib.parse.quote(title)}%22&max_results=1"
    try:
        req = urllib.request.urlopen(url)
        res = req.read().decode('utf-8')
        if "<id>" in res and "http://arxiv.org/abs/" in res:
            # find first id
            start = res.find("<id>") + 4
            end = res.find("</id>", start)
            arxiv_url = res[start:end]
            if "arxiv.org/abs/" in arxiv_url:
                arxiv_id = arxiv_url.split('/')[-1].split('v')[0]
                return arxiv_id
    except Exception as e:
        print(f"Error arxiv {title}: {e}")
    return None

def search_crossref(title):
    url = f"https://api.crossref.org/works?query.title={urllib.parse.quote(title)}&select=title,author,issued,DOI,URL&rows=1"
    try:
        req = urllib.request.urlopen(url)
        res = json.loads(req.read())
        items = res['message']['items']
        if items:
            return items[0]
    except Exception as e:
        print(f"Error crossref {title}: {e}")
    return None

for title in papers:
    print(f"\n--- Searching for: {title} ---")
    
    # Try crossref
    item = search_crossref(title)
    if item:
        print(f"Crossref found: {item.get('title', [''])[0]}")
        authors = []
        for a in item.get('author', []):
            authors.append(a.get('family', '') + ", " + a.get('given', ''))
        print(f"Authors: {' and '.join(authors)}")
        print(f"DOI: {item.get('DOI', '')}")
        year = item.get('issued', {}).get('date-parts', [[None]])[0][0]
        print(f"Year: {year}")
    
    # Try arxiv via crossref or arxiv API if needed. Let's just do another arxiv basic title search without quotes to be less restrictive
    url2 = f"http://export.arxiv.org/api/query?search_query=all:{urllib.parse.quote(title)}&max_results=1"
    try:
        req = urllib.request.urlopen(url2)
        res = req.read().decode('utf-8')
        start_title = res.find("<title>")
        # just print raw title and authors if found
        import xml.etree.ElementTree as ET
        root = ET.fromstring(res)
        ns = {'atom': 'http://www.w3.org/2005/Atom'}
        entries = root.findall('atom:entry', ns)
        if entries:
            entry = entries[0]
            print("Arxiv found:", entry.find('atom:title', ns).text.replace('\n', ' '))
            authors = [a.find('atom:name', ns).text for a in entry.findall('atom:author', ns)]
            print("Authors:", " and ".join(authors))
            print("Link:", entry.find('atom:id', ns).text)
            print("Published:", entry.find('atom:published', ns).text)
    except Exception as e:
        pass
        
    time.sleep(1)

