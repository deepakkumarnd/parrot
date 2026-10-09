require 'spec_helper'

describe Parrot::SearchIndex do
  subject(:index) { described_class.new }

  before do
    index.add(title: 'Learning Ruby', url: 'ruby.html', keywords: %w[ruby programming Guides])
    index.add(title: 'Rust for Rubyists', url: 'rust.html', keywords: %w[rust])
    index.add(title: 'Gardening', url: 'garden.html', keywords: ['Home & Garden'])
  end

  it 'lowercases and splits text into letter and digit runs' do
    expect(described_class.tokenize("Ruby's C-API, 2nd ed.")).to eq(%w[ruby s c api 2nd ed])
  end

  it 'keeps combining marks so Indic words stay whole' do
    expect(described_class.tokenize('മലയാളം ബ്ലോഗ്')).to eq(%w[മലയാളം ബ്ലോഗ്])
  end

  it 'finds posts by a prefix of any title word' do
    expect(index.lookup('learn')).to eq([{ 'title' => 'Learning Ruby', 'url' => 'ruby.html' }])
  end

  it 'finds posts by tag and category' do
    expect(index.lookup('program').map { |post| post['url'] }).to eq(%w[ruby.html])
    expect(index.lookup('guid').map { |post| post['url'] }).to eq(%w[ruby.html])
    expect(index.lookup('garden').map { |post| post['url'] }).to eq(%w[garden.html])
  end

  it 'matches case-insensitively' do
    expect(index.lookup('RUST').map { |post| post['url'] }).to eq(%w[rust.html])
  end

  it 'lists a post once even when several of its words match, in the order posts were added' do
    expect(index.lookup('ru').map { |post| post['url'] }).to eq(%w[ruby.html rust.html])
  end

  it 'returns nothing for an empty or unmatched prefix' do
    expect(index.lookup('')).to eq([])
    expect(index.lookup('python')).to eq([])
  end

  it 'serializes to posts plus a character trie with post ids under "$"' do
    data = JSON.parse(index.to_json)
    expect(data['posts'].length).to eq(3)
    expect(data['trie'].dig('r', 'u', 's', 't', '$')).to eq([1])
    expect(data['trie'].dig('r', 'u', 'b', 'y', '$')).to eq([0])
  end
end
