require 'unledge'

RSpec.describe Unledge do
  before(:all) do
    @unledge = Unledge::Unledge.new()
  end

  it 'has a version number' do
    expect(Unledge::VERSION).not_to be nil
  end

  it 'detects twitter urls' do
    uris = [
        [ 'http://twitter.com/foo/bar', true ],
        [ 'https://www.twitter.com/foo/bar', true ],
        [ 'https://mobile.twitter.com/foo/bar', true ],
        [ 'https://t.co/foo/bar', true ],
        [ 'https://gitt.co/foo/bar', false ],
        [ 'https://allatwitter.com/foo/bar', false ],
        [ 'https://nou.twitter.com/foo/bar', false ],
    ]

    uris.each { |pair|
      url = Urika.get_first_url(pair[0])
      matched = Unledge::Unledge.is_twitter_url(url)
      expect(!!matched).to eq(pair[1])
    }
  end

  it 'detects mastodon urls' do
    uris = [
        [ 'http://mastodon.social/@foo/bar', true ],
        [ 'https://wat.lgbt.io/@foo/bar', true ],
        [ 'https://joe:meh@foo.bar', false ],
        [ 'https://gitt.co/foo/@bar', false ],
    ]

    uris.each { |pair|
      url = Urika.get_first_url(pair[0])
      matched = Unledge::Unledge.is_mastodon_url(url)
      expect(!!matched).to eq(pair[1])
    }
  end

  it 'normalizes twitter urls' do
    uris = [
      [ 'http://twitter.com/foo/bar', 'mobile.twitter.com/foo/bar' ],
      [ 'https://www.twitter.com/foo/bar', 'mobile.twitter.com/foo/bar' ],
      [ 'https://mobile.twitter.com/foo/bar', 'mobile.twitter.com/foo/bar' ],
        [ 'https://t.co/foo/bar', 't.co/foo/bar' ],
        [ 'https://gitt.co/foo/bar', 'gitt.co/foo/bar' ],
        [ 'https://mobile.allatwitter.com/foo/bar', 'mobile.allatwitter.com/foo/bar' ],
    ]

    uris.each { |pair|
      url = Urika.get_first_url(pair[0])
      expect(Unledge::Unledge.normalize_url(url)).to eq(pair[1])
    }
  end

  it 'scrapes contents from tweets and toots' do
    tests = [
        [ 'test/tweet.html', :scrape_tweet, 'Tweet: feeldog dedass forgot how 내꺼 sounds like for a moment but he did the vocals dance rap wow wat a tru leader pic.twitter.com/e11N2tNUQ0' ],
        [ 'test/toot.html', :scrape_toot, 'Toot: My kids are obsessed with stroopwafels. I guess these things happen.' ],
        [ 'test/tweet_series.html', :scrape_tweet, 'Tweet: Cool looking student project that would probably get you a D in a games class and a cease and desist from Nintendo.' ],
        [ 'test/toot_series.html', :scrape_toot, 'Toot: I have to log off now, for several years.' ],
        [ 'test/tweet_multiline.html', :scrape_tweet, 'Tweet: Scott Baio is now boycotting Dick’s Sporting Goods due to their ban on Simi-automatic weapons   Dick’s Sporting Goods had to call in a replacement cashier to fill in for Scott pic.twitter.com/1AgJonovn7'],
        [ 'test/toot_ellipsized.html', :scrape_toot, 'Toot: Oh.  you would like me to test your application and write bug reports? *cracks knuckles*😈 You bet. https://cybre.space/media/LZMBWEgkic332LmLxCc (Scene from Death note, dramatically writing and eating chips: https://cybre.space/media/LZMBWEgkic332LmLxCc )' ],
        [ 'test/toot_pic.html', :scrape_toot, 'Toot: . ( https://mastodon.technology/media/L_TldXxzfh8IRyfepBE )' ],
        [ 'test/toot_begins_with_newline.html', :scrape_toot, 'Toot: a large bug fell on me ...upbeat sonic ost playlists will hopefully carry me through this fucking assignment (potentially the rest of the night, god)'],
        [ 'test/medium_article.html', :scrape_toot, nil ],
        [ 'test/tweet_embedded_status.html', :scrape_tweet, 'Tweet: it’s lit https://twitter.com/daniel_kraft/status/1182472433963425793  …'],
        [ 'test/tweet_embedded_video_format2.html', :scrape_tweet, 'Tweet: Kitteh tries ice cream.  pic.twitter.com/TZEEpzkEWq'],
        [ 'test/tweet_multiline_format2.html', :scrape_tweet, 'Tweet: Last year, things were going well at Star Theory, the independent video game studio behind Kerbal Space Program 2.   Then Take-Two cancelled their contract and tried to poach all their staff on LinkedIn.  My first big story for Bloomberg is a wild one:  bloomberg.com/news/articles/…'],
    ]

    tests.each { |test|
      expect(@unledge.dump(test[0]){ |doc| @unledge.send(test[1], doc)}).to eq(test[2])
    }
  end
end
