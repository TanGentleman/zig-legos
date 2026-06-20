const spider = @import("spider");

// This app embeds its page and assets with @embedFile and never uses spider's
// runtime template engine, so there is no views directory to load. Declaring this
// config (registered by build.zig as the `spider_config` import) is what stops the
// "No spider.config.zig found" and "views_dir not found" startup warnings — delete
// it only if you switch to runtime templates and point views_dir at a real folder.
pub const config = spider.Config{
    .views_dir = null, // no runtime templates — assets are embedded in the binary
    .env = .development,
    .port = 3000,
    .host = "127.0.0.1",
};
