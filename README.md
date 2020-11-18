# rcli

A command line interface for trying out [Repustate's multilingual semantic search](https://www.repustate.com/semantic-search/). 

## Install & Usage

1. [Download the binary for your OS](https://github.com/repustate/rcli/releases/). Make sure it's executable and in your path (otherwise prepend ./ to `rcli` below)
2. Run `rcli index -t "I love Repustate"` to index your first document.
3. Run `rcli search Org.business` to search your newly created index.
4. Run `rcli help` to see available commands and other options.

## What is semantic search?

In traditional free text search applications, you use keywords and optionally
boolean operators to perform lexical matches against the text without actually
understanding what the text is about semantically. 

Semantic search attempts to understand the topics, entities, themes etc.
mentioned in the text document (or video, audio, image file) and expose them as
searchable elements at a very high level. For more concrete examples, consider
the following problems and ask yourself how you'd solve these using keywords:

1. Find all pharmaceutical drugs mentioned in a collection of patents
2. Find any female US politician under the age of 50 mentioned in a collection of Tweets
3. Find any local news videos about locations within 10km of your house

## What is the multilingual part about?

This semantic search technology works in any of the over 20 languages Repustate
currently supports and it allows you to store documents in one (or more)
languages and retrieve them using English. That means you can have a corpus of
Russian and Arabic text but search it using English queries.

## About this demo

This demo allows you to create your own semantic search index, index any text
documents you have and make some queries, all from your shell, all for free.
Your index (and all of the data you indexed) will be deleted after 24 hours -
this is just to give you a taste of Repustate's semantic technology. Please
[contact us](https://www.repustate.com/contact/) if you're interested in a
commercial license.

## Searching

At present, Repustate's semantic search requires you construct your queries
using our own query language. Future releases will allow for pure natural
language queries. To see a list of available semantic search terms, run `rcli search --list-terms`

This demo is quite limited in the search capabilities it exposes. Visit the
[semantic search](https://www.repustate.com/semantic-search/) page to get a
fuller understanding of what this platform is capable of.

## Roadmap

Future releases of this demo tool will allow for the following:

1. Pure natural language search in any language Repustate supports
2. Indexing video, images, and audio
3. More supported languages (Maltese, Slovenian, Swahili and more!)

## More details about the commercial product

Repustate's semantic search platform is ready for prime-time and is available
for commercial use right now. The API is a very simple RESTful API and your
search index can be self-hosted on-premise or you can use our cloud storage.
Any text, video and audio can be indexed and searched in any of our supported
languages.

## Feedback? Questions?

[Get in touch!](https://www.repustate.com) 
