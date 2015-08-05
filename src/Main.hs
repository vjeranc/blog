--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Text.Pandoc
import           Text.Pandoc.Options
import           System.FilePath.Posix  (takeBaseName, takeDirectory, (</>),
                                         splitFileName)
import           Data.List (isInfixOf)
import qualified Data.Set as S
import           Data.Binary
import           System.IO.Unsafe
--------------------------------------------------------------------------------
images = do
  match "images/*" $ do
      route   idRoute
      compile copyFileCompiler
cssfiles = do
  match "css/*" $ do
      route   idRoute
      compile compressCssCompiler
fonts = do
  match "font/*" $ do
      route idRoute
      compile copyFileCompiler

aboutNcontact xs template = do
  match (fromList xs) $ do
      route   niceRoute
      compile $ pandocCompiler
          >>= loadAndApplyTemplate template defaultContext
          >>= prettifyUrl

posts path postTemplate defaultTemplate feedSnapshotName = do
  match path $ do
      route niceRoute
      compile $ do
        ident <- getUnderlying
        toc   <- getMetadataField ident "toc"
        mathTex <- getMetadataField ident "mathjax"
        let tocWriterSettings =
              case toc of
                Just "yes" -> myWriterOptionsToc
                Nothing    -> myWriterOptions
        let postCtxMath =
              case mathTex of
                Just "yes" -> constField "mathjax" "here" `mappend` postCtx
                _          -> postCtx
        let writerSettings =
              case mathTex of
                Just "yes" -> addMathJaxPandoc tocWriterSettings
                _          -> tocWriterSettings
        pandocCompilerWith defaultHakyllReaderOptions writerSettings
          >>= loadAndApplyTemplate postTemplate    postCtxMath
          >>= saveSnapshot feedSnapshotName
          >>= loadAndApplyTemplate defaultTemplate postCtxMath
          >>= prettifyUrl

archive xs postsPath title archiveTemplate defaultTemplate = do
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

indexPage name title postsPath defaultTemplate = do
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

atomFeed xs postsPath snapshotName = do
  create xs $ do
    route idRoute
    compile $ do
        let feedCtx = postCtx `mappend` bodyField "description"
        posts <- fmap (take 10) . recentFirst =<<
            loadAllSnapshots postsPath snapshotName
        renderAtom myFeedConfiguration feedCtx posts

fourOhFour = do
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

    posts "posts/*" "templates/post.html" "templates/default.html" "feed"
    posts "hr/clanci/*" "templates/post-hr.html" "templates/default-hr.html" "feed-hr"

    archive ["archive.html"] "posts/*" "Archives" "templates/archive.html" "templates/default.html"
    archive ["hr/arhiva.html"]  "hr/clanci/*" "Arhiva" "templates/arhiva.html" "templates/default-hr.html"

    indexPage "index.html" "Home" "posts/*" "templates/default.html"
    indexPage "hr/index.html" "Početna" "hr/clanci/*" "templates/default-hr.html"

    match "templates/*" $ compile templateCompiler

    atomFeed ["atom.xml"] "posts/*" "feed"
    atomFeed ["hr/atom.xml"] "hr/clanci/*" "feed-hr"


--------------------------------------------------------------------------------
addMathJaxPandoc writerOptions =
  let mathExtensions = [Ext_tex_math_dollars, Ext_tex_math_double_backslash,
                        Ext_latex_macros]
      extensions = writerExtensions writerOptions
      newExtensions = foldr S.insert extensions mathExtensions
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
            where isLocal uri = not (isInfixOf "://" uri)
--------------------------------------------------------------------------------
myWriterOptions :: WriterOptions
myWriterOptions = defaultHakyllWriterOptions {
      writerReferenceLinks = True
    , writerHtml5 = True
    , writerHighlight = True
    }

myWriterOptionsToc :: WriterOptions
myWriterOptionsToc = myWriterOptions {
      writerTableOfContents = True
    , writerTOCDepth = 3
    , writerTemplate = "$if(toc)$<div id=\"toc\">$toc$</div>$endif$\n$body$"
    , writerStandalone = True
    }

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
