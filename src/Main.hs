--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Text.Pandoc
import           Text.Pandoc.Options
import           System.FilePath.Posix  (takeBaseName, takeDirectory, (</>),
                                         splitFileName)
import           Data.List (isInfixOf)
import qualified Data.Set as S
import qualified Data.Map as M
import           Data.Binary
import           System.IO.Unsafe
import           Debug.Trace
import qualified Text.CSL as CSL
import           Text.CSL.Pandoc (processCites)
--------------------------------------------------------------------------------
images =
  match "images/*" $ do
      route   idRoute
      compile copyFileCompiler
cssfiles =
  match "css/*" $ do
      route   idRoute
      compile compressCssCompiler
fonts =
  match "font/**" $ do
      route idRoute
      compile copyFileCompiler

aboutNcontact xs template =
  match (fromList xs) $ do
      route   niceRoute
      compile $ pandocCompilerWith defaultHakyllReaderOptions myWriterOptions
          >>= loadAndApplyTemplate template defaultContext
          >>= prettifyUrl

posts path postTemplate defaultTemplate feedSnapshotName =
  match path $ do
      route niceRoute
      compile $ do
        ident <- getUnderlying
        toc   <- getMetadataField ident "toc"
        mathTex <- getMetadataField ident "mathjax"
        bibtexPath <- getMetadataField ident "references"

        let tocWriterSettings =
              case toc of
                Just "true" -> myWriterOptionsToc
                _           -> myWriterOptions
        let postCtxMath =
              case mathTex of
                Just "true" -> constField "mathjax" "here" `mappend` postCtx
                _           -> postCtx
        let wopts =
              case mathTex of
                Just "true" -> addMathJaxPandoc tocWriterSettings
                _           -> tocWriterSettings
        let ropts = defaultHakyllReaderOptions

        (case bibtexPath of
          Just bib -> bibtexCompilerWith ropts wopts bib "elsevier.csl"
          _        -> pandocCompilerWith ropts wopts)
          >>= loadAndApplyTemplate postTemplate    postCtxMath
          >>= saveSnapshot feedSnapshotName
          >>= loadAndApplyTemplate defaultTemplate postCtxMath
          >>= prettifyUrl

archive xs postsPath title archiveTemplate defaultTemplate =
  create xs $ do
      route niceRoute
      compile $ do
          posts <- recentFirst =<< loadAll postsPath
          let archiveCtx =
                  listField "posts" postCtx (return posts) `mappend`
                  constField "title" title            `mappend`
                  defaultContext

          makeItem ""
              >>= loadAndApplyTemplate archiveTemplate archiveCtx
              >>= loadAndApplyTemplate defaultTemplate archiveCtx
              >>= prettifyUrl

indexPage name title postsPath defaultTemplate =
  match name $ do
    route idRoute
    compile $ do
        posts <- recentFirst =<< loadAll postsPath
        let indexCtx =
                listField "posts" postCtx (return posts) `mappend`
                constField "title" title                `mappend`
                defaultContext

        getResourceBody
            >>= applyAsTemplate indexCtx
            >>= loadAndApplyTemplate defaultTemplate indexCtx
            >>= prettifyUrl

atomFeed xs postsPath snapshotName =
  create xs $ do
    route idRoute
    compile $ do
        let feedCtx = postCtx `mappend` bodyField "description"
        posts <- fmap (take 10) . recentFirst =<<
            loadAllSnapshots postsPath snapshotName
        renderAtom myFeedConfiguration feedCtx posts

fourOhFour =
  match "404.markdown" $ do
      route   idRoute
      compile copyFileCompiler

main :: IO ()
main = hakyll $ do
    images

    cssfiles

    fonts

    aboutNcontact ["about.rst", "contact.markdown"] "templates/default.html"
    aboutNcontact ["hr/o-stranici.markdown", "hr/kontakt.markdown"] "templates/default-hr.html"

    match "elsevier.csl" $ compile cslCompiler
    match "bib/*" $ compile biblioCompiler

    posts "posts/*" "templates/post.html" "templates/default.html" "feed"
    posts "hr/clanci/*" "templates/post-hr.html" "templates/default-hr.html" "feed-hr"

    archive ["archive.html"] "posts/*" "Archives" "templates/archive.html" "templates/default.html"
    archive ["hr/arhiva.html"]  "hr/clanci/*" "Arhiva" "templates/arhiva.html" "templates/default-hr.html"

    indexPage "index.html" "Home" "posts/*" "templates/default.html"
    indexPage "hr/index.html" "Početna" "hr/clanci/*" "templates/default-hr.html"

    match "templates/*" $ compile templateCompiler

    atomFeed ["atom.xml"] "posts/*" "feed"
    atomFeed ["hr/atom.xml"] "hr/clanci/*" "feed-hr"

    fourOhFour

--------------------------------------------------------------------------------
addLinkCitations (Pandoc meta a) =
  let prevMap = unMeta meta
      newMap = M.insert "reference-section-title" (MetaString "Bibliography") $ 
               M.insert "link-citations" (MetaBool True) prevMap
      newMeta = Meta newMap
  in  Pandoc newMeta a

myReadPandocBiblio :: ReaderOptions
                   -> Item CSL
                   -> Item Biblio
                   -> Item String
                   -> Compiler (Item Pandoc)
myReadPandocBiblio ropt csl biblio item = do
    -- Parse CSL file, if given
    style <- unsafeCompiler $ CSL.readCSLFile Nothing . toFilePath . itemIdentifier $ csl

    -- We need to know the citation keys, add then *before* actually parsing the
    -- actual page. If we don't do this, pandoc won't even consider them
    -- citations!
    let Biblio refs = itemBody biblio
    pandoc <- itemBody <$> readPandocWith ropt item
    let pandoc' = processCites style refs (addLinkCitations pandoc)

    return $ fmap (const pandoc') item

bibtexCompilerWith readerOpts writerOpts bibPath cslPath = do
  csl <- load cslPath
  bib <- load (fromFilePath bibPath)

  getResourceBody
    >>= myReadPandocBiblio readerOpts csl bib
    >>= return . writePandocWith writerOpts

addMathJaxPandoc writerOptions =
  let mathExtensions = [Ext_tex_math_dollars, Ext_tex_math_double_backslash,
                        Ext_latex_macros]
      extensions = writerExtensions writerOptions
      newExtensions = foldr enableExtension extensions mathExtensions
      mathJaxWriterOptions = writerOptions {
                          writerExtensions = newExtensions,
                          writerHTMLMathMethod = MathJax ""
                        }
  in mathJaxWriterOptions

prettifyUrl :: Item String -> Compiler (Item String)
prettifyUrl x = relativizeUrls x >>= removeIndexHtml

niceRoute :: Routes
niceRoute = customRoute createIndexRoute
  where createIndexRoute ident =
          let p = toFilePath ident
          in takeDirectory p </> takeBaseName p </> "index.html"

removeIndexHtml :: Item String -> Compiler (Item String)
removeIndexHtml item = return $ fmap (withUrls removeIndexStr) item
  where removeIndexStr url =
          case splitFileName url of
            (dir, "index.html") | isLocal dir -> dir
            _                                 -> url
            where isLocal uri = not ("://" `isInfixOf` uri)
--------------------------------------------------------------------------------
myWriterOptions :: WriterOptions
myWriterOptions = defaultHakyllWriterOptions {
      writerReferenceLinks = True
    , writerEmailObfuscation = JavascriptObfuscation
    }

myWriterOptionsToc :: WriterOptions
myWriterOptionsToc = myWriterOptions {
      writerTableOfContents = True
    , writerTOCDepth = 4
    , writerTemplate = Just tocTemplate
    }
  where tocTemplate = either error id $ either (error . show) id $
                      runPure $ runWithDefaultPartials $
                      compileTemplate "" "$if(toc)$<div id=\"toc\">$toc$</div>$endif$\n$body$"

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Post feed - Ante portas"
    , feedDescription = "Feed contains Vjeran's blog posts."
    , feedAuthorName  = "Vjeran Crnjak"
    , feedAuthorEmail = "vjeran.crnjak@gmail.com"
    , feedRoot        = "http://vjerancrnjak.me"
    }


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%Y-%m-%d" `mappend`
    defaultContext
