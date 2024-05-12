
#if defined( __clang__ )
  #define CCOMP clang
#elif defined( _MSC_VER )
  #define CCOMP msvc
#elif defined( __GNUC__ )
  #define CCOMP gcc
#else
  #define CCOMP other
#endif

CCOMP
