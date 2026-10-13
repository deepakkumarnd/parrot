module Parrot
  # The skeleton blog `parrot new` copies. Some of its files are used by the
  # build even in blogs made before they existed: a blog's own copy wins,
  # and the skeleton's is used when it has none.
  module Skeleton
    DIR = File.expand_path('../../skel', __dir__)

    module_function

    # The blog's copy of a skeleton file (given relative to the blog's
    # root), or the skeleton's own when the blog doesn't have one.
    def path(app_root, relative)
      own = File.join(app_root, relative)
      File.exist?(own) ? own : File.join(DIR, relative)
    end
  end
end
