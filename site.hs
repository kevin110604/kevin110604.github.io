{-# LANGUAGE OverloadedStrings #-}
import           Data.String (fromString)
import           Data.Monoid (mappend)
import           Data.Maybe  (fromMaybe)
import           Control.Monad (liftM)
import           Control.Applicative ((<$>))
import           Hakyll
import           Text.Pandoc.Options        -- For customized Pandoc options

postsPageId :: PageNumber -> Identifier
postsPageId n = fromFilePath $ case n of 1 -> "archive/1999-12-02-samplePost.md"
                                         2 -> "archive/2015-08-12-spqr.markdown"
                                         3 -> "archive/2015-10-07-rosa-rosa-rosam.markdown"
                                         4 -> "archive/2015-11-28-carpe-diem.markdown"
                                         5 -> "archive/2015-12-07-tu-quoque.markdown"

postsGrouper :: (MonadFail m, MonadMetadata m) => [Identifier] -> m [[Identifier]]
postsGrouper = liftM (paginateEvery 1) . sortRecentFirst

main :: IO ()
main = hakyllWith config $ do
    match "assets/*" $ do
        route   $ idRoute
        compile $ copyFileCompiler
    
    match "images/*" $ do
        route   $ idRoute
        compile $ copyFileCompiler

    match "css/*" $ do
        route   $ idRoute
        compile $ compressCssCompiler
    
    match "templates/*" $ do 
        compile $ templateBodyCompiler
    
    match "archive/*" $ version "firstVer" $ do
        compile $ 
            pandocCompilerWith customReaderOptions customWriterOptions

    paginate <- buildPaginateWith postsGrouper "archive/*" postsPageId

    paginateRules paginate $ \page pattern -> do
        route   $ setExtension "html"
        compile $ do
            iden <- getUnderlying
            let id = setVersion (Just "firstVer") iden
            item <- load id :: Compiler (Item String)
            meta <- getMetadata id
            let indexCtx =
                    paginateContext paginate page                                           `mappend`
                    postCtx                                                               `mappend`
                    constField "title" (fromMaybe "No title" $ lookupString "title" meta) `mappend`
                    constField "body" (itemBody item)
            
            pandocCompilerWith customReaderOptions customWriterOptions
                >>= loadAndApplyTemplate "templates/post.html"    indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "menu/about.md" $ do
        route   $ gsubRoute "menu/" (const "") `composeRoutes` setExtension "html"
        compile $ do 
            pandocCompiler
                >>= loadAndApplyTemplate "templates/non-post.html" defaultContext
                >>= loadAndApplyTemplate "templates/default.html" defaultContext
                >>= relativizeUrls
    
    match "menu/archive.md" $ do
        route   $ constRoute "archive/index.html"
        compile $ do
            posts <- recentFirst =<< loadAll "archive/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext
            pandocCompiler
                >>= loadAndApplyTemplate "templates/non-post.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "menu/home.md" $ do 
        route   $ constRoute "index.html"
        compile $ do
            pandocCompiler
                >>= loadAndApplyTemplate "templates/non-post.html" defaultContext
                >>= loadAndApplyTemplate "templates/default.html" defaultContext
                >>= relativizeUrls

-- Customized config
config :: Configuration
config = defaultConfiguration
    { previewHost          = "0.0.0.0" }

-- Create a context containing $date$ field for posts
postCtx :: Context String
postCtx =
    dateField "date" "%b %e, %Y" `mappend`
    tagsCtx                      `mappend`
    defaultContext

-- Create a context containing $tags$ (which is a listField)
    -- listFieldWith :: String -> Context a -> (Item b -> Compiler [Item a]) -> Context b
        -- Creates a list field like listField, but supplies the current page (i.e item) to the compiler
    -- getMetadataField :: MonadMetadata m => Identifier -> String -> m (Maybe String)
        -- Get the content of corresponding field
tagsCtx :: Context String
tagsCtx = listFieldWith "tags" tagElementCtx getTags
    where tagElementCtx = field "tagElement" (return . itemBody)
          getTags = (\item -> do
              tags <- getMetadataField (itemIdentifier item) "tags"
              return $ case tags of
                  Just lst -> map mkItem $ splitAll "," lst
                  Nothing  -> [] )
              where mkItem tagElement = Item {
                  itemIdentifier = fromString tagElement,
                  itemBody       = '#' : tagElement }

-- Customize Pandoc options
customReaderOptions = defaultHakyllReaderOptions
    { readerExtensions = extensionsFromList ext_list }

customWriterOptions = defaultHakyllWriterOptions
    { writerExtensions = extensionsFromList ext_list 
    , writerHTMLMathMethod = MathJax defaultMathJaxURL
    }

ext_list = 
    [ Ext_footnotes
    , Ext_inline_notes
    , Ext_pandoc_title_block
    , Ext_yaml_metadata_block
    , Ext_table_captions
    , Ext_implicit_figures
    , Ext_simple_tables
    , Ext_multiline_tables
    , Ext_grid_tables
    , Ext_pipe_tables
    , Ext_citations
    , Ext_emoji
    , Ext_raw_tex
    , Ext_raw_html
    , Ext_tex_math_dollars
    , Ext_tex_math_double_backslash
    , Ext_tex_math_single_backslash
    , Ext_latex_macros
    , Ext_fenced_code_blocks
    , Ext_fenced_code_attributes
    , Ext_backtick_code_blocks
    , Ext_inline_code_attributes
    , Ext_raw_attribute
    , Ext_markdown_in_html_blocks
    , Ext_native_divs
    , Ext_fenced_divs
    , Ext_native_spans
    , Ext_bracketed_spans
    , Ext_escaped_line_breaks
    , Ext_fancy_lists
    , Ext_startnum
    , Ext_definition_lists
    , Ext_example_lists
    , Ext_all_symbols_escapable
    , Ext_intraword_underscores
    , Ext_blank_before_blockquote
    , Ext_blank_before_header
    , Ext_space_in_atx_header
    , Ext_strikeout
    , Ext_superscript
    , Ext_subscript
    , Ext_task_lists
    , Ext_auto_identifiers
    , Ext_header_attributes
    , Ext_link_attributes
    , Ext_implicit_header_references
    , Ext_line_blocks
    , Ext_shortcut_reference_links
    , Ext_smart
    ]