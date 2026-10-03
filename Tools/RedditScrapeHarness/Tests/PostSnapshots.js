(snapshotReader) => {
  const parse = html => {
    const document = new DOMParser().parseFromString(html, 'text/html');
    const reader = new Function('document', 'location', `return (${snapshotReader})('testpost');`);
    return JSON.parse(reader(document, {origin: 'https://www.reddit.com'}));
  };
  const post = (attributes, body) => `<shreddit-post id="t3_testpost" ${attributes}>${body}</shreddit-post>`;
  const cases = [
    {
      name: 'Focal body excludes navigation and other posts',
      html: '<nav>Join Reddit</nav><shreddit-post id="t3_other"><p>Recommendation</p></shreddit-post>' +
        post('post-type="text"', '<div slot="credit-bar">Community</div>' +
          '<div property="schema:articleBody"><p>Actual body</p></div>'),
      check: result => result.found && result.bodyHTML === '<p>Actual body</p>'
    },
    {
      name: 'Missing focal post never extracts recommendations',
      html: '<shreddit-post id="t3_other"><p>Recommendation</p></shreddit-post>',
      check: result => !result.found && !result.bodyHTML
    },
    {
      name: 'Image uses original URL once',
      html: post('post-type="image" content-href="https://i.redd.it/original.png"',
        '<div slot="post-media-container"><img src="https://preview.redd.it/small.png"></div>'),
      check: result => result.imageURLs.length === 1 && result.imageURLs[0].includes('original.png')
    },
    {
      name: 'Gallery preserves order and excludes community icon',
      html: post('post-type="gallery"', '<img src="https://example.com/icon.png">' +
        '<div slot="post-media-container"><li slot="page-1">' +
        '<img role="presentation" src="https://preview.redd.it/first.jpg">' +
        '<img src="https://preview.redd.it/first.jpg">' +
        '<zoomable-img><img src="https://i.redd.it/first.jpg"></zoomable-img></li>' +
        '<li slot="page-2"><img data-lazy-src="https://i.redd.it/second.jpg"></li></div>'),
      check: result => result.imageURLs.join(',') === 'https://i.redd.it/first.jpg,https://i.redd.it/second.jpg'
    },
    {
      name: 'Video keeps HLS URL and caption',
      html: post('post-type="video"', '<div slot="post-media-container">' +
        '<shreddit-player src="https://v.redd.it/video/HLSPlaylist.m3u8?audio=1"></shreddit-player></div>' +
        '<div property="schema:articleBody"><p>Caption</p></div>'),
      check: result => result.videoURL.endsWith('?audio=1') && result.bodyHTML.includes('Caption')
    },
    {
      name: 'External link routes to original content',
      html: post('post-type="link" content-href="https://example.com/story"', ''),
      check: result => result.linkedURL === 'https://example.com/story'
    },
    {
      name: 'Unsafe link is rejected',
      html: post('post-type="link" content-href="javascript:alert(1)"', ''),
      check: result => result.linkedURL === null
    },
    {
      name: 'Post text about challenges is not a challenge page',
      html: post('post-type="text"',
        '<div property="schema:articleBody"><p>Why do websites ask me to prove you are human?</p></div>'),
      check: result => result.found && !result.challenge
    },
    {
      name: 'Challenge is detected',
      html: '<form action="/challenge"><p>Prove you are human</p></form>',
      check: result => result.challenge
    }
  ];
  return cases.map(testCase => ({name: testCase.name, passed: testCase.check(parse(testCase.html))}));
}
