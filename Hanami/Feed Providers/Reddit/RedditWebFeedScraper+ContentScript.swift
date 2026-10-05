import Foundation

extension RedditWebFeedScraper {
    static let postSnapshotScript = #"""
    (postID) => {
      const post = Array.from(document.querySelectorAll('shreddit-post')).find(element =>
        [element.id, element.getAttribute('post-id')].includes('t3_' + postID) ||
        (element.getAttribute('permalink') || '').includes('/comments/' + postID + '/'));
      const bodyText = document.body.innerText.toLowerCase();
      const challenge = !!document.querySelector('form[action*="challenge"]') ||
        (!post && bodyText.includes('prove you are human')) || document.title.toLowerCase() === 'blocked';
      const absoluteURL = value => {
        if (!value) return null;
        try {
          const url = new URL(value, location.origin);
          return ['http:', 'https:'].includes(url.protocol) ? url.href : null;
        } catch { return null; }
      };
      const result = {found: !!post, challenge, bodyHTML: '', imageURLs: [], videoURL: null, linkedURL: null};
      if (!post) return JSON.stringify(result);
      const body = post.querySelector('[property="schema:articleBody"], [id$="-post-rtjson-content"]');
      result.bodyHTML = body?.innerHTML || '';
      const postType = post.getAttribute('post-type');
      const contentURL = absoluteURL(post.getAttribute('content-href') || '');
      const media = post.querySelector('[slot="post-media-container"]');
      const player = media?.querySelector('shreddit-player');
      result.videoURL = absoluteURL(player?.getAttribute('src') ||
        media?.querySelector('video source, video[src], source[type="application/vnd.apple.mpegURL"]')
          ?.getAttribute('src') || '');
      if (postType === 'image' && contentURL) result.imageURLs.push(contentURL);
      if (!result.videoURL && (postType === 'gallery' || (postType === 'image' && !contentURL))) {
        const galleryPages = Array.from(media?.querySelectorAll('li[slot^="page-"]') || []);
        const images = galleryPages.length ? galleryPages.map(page =>
          page.querySelector('zoomable-img img') || page.querySelector('img:not([role="presentation"])')) :
          Array.from(media?.querySelectorAll('img:not([role="presentation"])') || []);
        for (const image of images.filter(Boolean)) {
          if (image.closest('shreddit-post') !== post) continue;
          const imageURL = absoluteURL(image.getAttribute('src') || image.getAttribute('data-lazy-src') || '');
          if (imageURL && !result.imageURLs.includes(imageURL)) result.imageURLs.push(imageURL);
        }
      }
      if (postType === 'link' && contentURL) {
        const hostname = new URL(contentURL).hostname;
        if (!/(^|\.)(reddit\.com|redd\.it)$/.test(hostname)) result.linkedURL = contentURL;
      }
      return JSON.stringify(result);
    }
    """#
}
