#!/usr/bin/env python3
"""Fills a simulator's Sakura database with the sample library used for screenshots.

    seed.py --language en --container <app group container> --ids-out ids.tsv

Everything comes from Feeds/*.json, Bodies/<language>/*.md and library.json, so nothing
is fetched: articles are dated relative to now, and images are mesh gradients written
straight into the app's image cache under made-up URLs.
"""

import argparse
import hashlib
import json
import sqlite3
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from artwork import feed_icon, jpeg_bytes, mesh_gradient, rng_for

SEED_DIR = Path(__file__).resolve().parent
IMAGE_HOST = "https://images.kivotos.example"
# Matches ContentResolver.parserVersion, so the reader shows the stored body instead of fetching.
PARSER_VERSION = 20261003000000

SAMPLE_TABLES = [
    "bookmark_tag_items", "bookmark_tags", "bookmark_folder_items", "list_feeds", "list_rules", "lists",
    "nlp_entities", "similar_articles", "summary_headlines", "comments", "image_cache", "articles", "feeds",
]


class Seeder:

    def __init__(self, language, container):
        self.language = language
        self.container = container
        self.database = sqlite3.connect(container / "Sakura.feeds")
        self.library = json.loads((SEED_DIR / "library.json").read_text())
        self.feeds = [json.loads(path.read_text()) for path in sorted((SEED_DIR / "Feeds").glob("*.json"))]
        self.now = time.time()
        self.feed_ids = {}
        self.article_ids = {}

    def text(self, localized):
        return localized.get(self.language) or localized["en"]

    def entity_name(self, name):
        return self.library["entityNames"].get(self.language, {}).get(name, name)

    def cache_image(self, name, width, height, hue):
        url = f"{IMAGE_HOST}/{name}.jpg"
        self.database.execute(
            "INSERT OR REPLACE INTO image_cache (url, data, cached_at) VALUES (?, ?, ?)",
            (url, jpeg_bytes(mesh_gradient(name, width, height, hue)), self.now),
        )
        return url

    def clear(self):
        for table in SAMPLE_TABLES:
            self.database.execute(f"DELETE FROM {table}")
        icon_dir = self.container / "FaviconCache"
        for path in icon_dir.glob("custom-feed-*"):
            path.unlink()

    def seed(self):
        self.clear()
        for feed in self.feeds:
            self.insert_feed(feed)
        self.insert_lists()
        self.file_bookmarks()
        self.database.executemany(
            "UPDATE articles SET is_read = 1 WHERE id = ?",
            [(self.article_ids[slug],) for slug in self.library["read"]],
        )
        self.database.commit()

    def insert_feed(self, feed):
        kind = feed.get("kind", "news")
        cursor = self.database.execute(
            """INSERT INTO feeds (title, url, site_url, last_fetched, is_podcast, is_fediverse,
                   custom_icon_url, is_title_customized, sync_id, user_modified_at)
               VALUES (?, ?, ?, ?, ?, ?, 'photo', 1, ?, ?)""",
            (self.text(feed["title"]), feed["url"], feed["site"], self.now,
             int(kind == "podcast"), int(kind == "fediverse"), str(uuid.uuid4()).upper(), self.now),
        )
        feed_id = cursor.lastrowid
        self.feed_ids[feed["key"]] = feed_id
        icon_dir = self.container / "FaviconCache"
        icon_dir.mkdir(exist_ok=True)
        (icon_dir / f"custom-feed-{feed_id}.png").write_bytes(feed_icon(feed))
        for article in feed["articles"]:
            self.insert_article(feed, feed_id, kind, article)

    def insert_article(self, feed, feed_id, kind, article):
        slug = article["slug"]
        published = self.now - article["age"] * 60
        image_url = self.article_image(feed, kind, article)
        audio_url = f"https://audio.kivotos.example/{slug}.mp3" if kind == "podcast" else None
        content = self.body(article, feed["hue"])
        summary = (self.status_summary(article, published) if kind == "status"
                   else self.text(article["summary"]))
        cursor = self.database.execute(
            """INSERT INTO articles (feed_id, title, url, author, summary, content, image_url,
                   published_date, audio_url, duration, has_full_text, parser_version,
                   sentiment_processed, entities_processed, similar_computed)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, 1)""",
            (feed_id, self.text(article["title"]), self.article_url(feed, kind, article),
             article.get("author"), summary, content, image_url, published, audio_url,
             article.get("duration"), int(content is not None),
             PARSER_VERSION if content is not None else 0),
        )
        article_id = cursor.lastrowid
        self.article_ids[slug] = article_id
        self.database.executemany(
            "INSERT INTO nlp_entities (article_id, name, type) VALUES (?, ?, ?)",
            [(article_id, self.entity_name(name), kind_name) for name, kind_name in article.get("entities", [])],
        )

    def article_url(self, feed, kind, article):
        slug = article["slug"]
        if kind == "video":
            # YouTube-shaped, so the app treats it as a video. Made-up IDs never play, so the
            # one opened in the iPad player names a real, openly licensed video instead.
            video_id = article.get("youtube", {}).get("id") or hashlib.sha256(slug.encode()).hexdigest()[:11]
            return "https://www.youtube.com/watch?v=" + video_id
        if kind == "reddit":
            return f"https://www.reddit.com/r/Kivotos/comments/{hashlib.sha256(slug.encode()).hexdigest()[:6]}/{slug}/"
        return f"{feed['site'].rstrip('/')}/{slug}"

    def article_image(self, feed, kind, article):
        if kind == "status" or not article.get("image", True):
            return None
        if kind == "podcast":
            return self.cache_image(feed["key"] + "-cover", 1000, 1000, feed["hue"])
        if kind == "video":
            return self.cache_image(article["slug"], 1280, 720, feed["hue"])
        if kind == "reddit":
            width, height = rng_for(article["slug"]).choice([(1080, 1350), (1080, 1080), (1350, 1080)])
            return self.cache_image(article["slug"], width, height, (feed["hue"] + rng_for(article["slug"]).randint(0, 359)) % 360)
        return self.cache_image(article["slug"], 1200, 800, feed["hue"])

    def body(self, article, hue):
        if "body" not in article:
            return None
        markdown = (SEED_DIR / "Bodies" / self.language / f"{article['body']}.md").read_text()
        # The reader places images from its own {{IMG}} markers, not Markdown image syntax.
        while "![](image:" in markdown:
            start = markdown.index("![](image:")
            end = markdown.index(")", start)
            name = markdown[start + len("![](image:"):end]
            url = self.cache_image(name, 1600, 900, hue)
            markdown = markdown[:start] + "{{IMG}}" + url + "{{/IMG}}" + markdown[end + 1:]
        return markdown

    def status_summary(self, article, published):
        """Statuspage's format: newest update first, each under its own timestamp."""
        lines = []
        for update in sorted(article["updates"], key=lambda update: -update["after"]):
            stamp = datetime.fromtimestamp(published + update["after"] * 60, tz=timezone.utc)
            lines.append(f"{stamp.strftime('%b %e, %H:%M')} UTC\n"
                         f" **{self.text(update['status'])}** - {self.text(update['text'])}")
        return "\n  ".join(lines)

    def insert_lists(self):
        for order, sample_list in enumerate(self.library["lists"]):
            cursor = self.database.execute(
                "INSERT INTO lists (name, sort_order) VALUES (?, ?)", (self.text(sample_list["name"]), order)
            )
            self.database.executemany(
                "INSERT INTO list_feeds (list_id, feed_id) VALUES (?, ?)",
                [(cursor.lastrowid, self.feed_ids[key]) for key in sample_list["feeds"]],
            )

    def file_bookmarks(self):
        """The app creates its default folders on first launch; they are renamed into this language."""
        for icon, name in self.library["bookmarkFolders"].items():
            self.database.execute("UPDATE bookmark_folders SET name = ? WHERE icon = ?", (self.text(name), icon))
        # "unsorted" bookmarks sit in no folder, which is the group the Bookmarks page opens on.
        for icon, slugs in self.library["bookmarks"].items():
            folder = self.database.execute("SELECT id FROM bookmark_folders WHERE icon = ?", (icon,)).fetchone()
            for slug in slugs:
                article_id = self.article_ids[slug]
                self.database.execute("UPDATE articles SET is_bookmarked = 1 WHERE id = ?", (article_id,))
                if folder:
                    self.database.execute(
                        "INSERT INTO bookmark_folder_items (folder_id, article_id) VALUES (?, ?)",
                        (folder[0], article_id),
                    )
        for tag in self.library["bookmarkTags"]:
            name = self.text(tag["name"])
            cursor = self.database.execute(
                "INSERT INTO bookmark_tags (name, normalized_name, is_automatic) VALUES (?, ?, 0)",
                (name, name.lower()),
            )
            for slug in tag["articles"]:
                article_id = self.article_ids[slug]
                self.database.execute("UPDATE articles SET is_bookmarked = 1 WHERE id = ?", (article_id,))
                self.database.execute(
                    "INSERT INTO bookmark_tag_items (tag_id, article_id) VALUES (?, ?)", (cursor.lastrowid, article_id)
                )

    def write_ids(self, path):
        lines = [f"{key}\t{feed_id}" for key, feed_id in self.feed_ids.items()]
        lines += [f"article:{slug}\t{article_id}" for slug, article_id in self.article_ids.items()]
        path.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--language", default="en")
    parser.add_argument("--container", type=Path, required=True)
    parser.add_argument("--ids-out", type=Path, required=True)
    arguments = parser.parse_args()
    seeder = Seeder(arguments.language, arguments.container)
    seeder.seed()
    seeder.write_ids(arguments.ids_out)
    print(f"seeded {len(seeder.feed_ids)} feeds and {len(seeder.article_ids)} articles ({arguments.language})")


if __name__ == "__main__":
    main()
