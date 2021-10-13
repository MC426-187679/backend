#include <string>
#include <rapidfuzz/fuzz.hpp>

// Escolha do tipo de ratio para o fuzzy matching.
#ifndef RATIO_TYPE
#warning "RATIO_TYPE undefined, defaulting to CachedRatio"
#define RATIO_TYPE CachedRatio
#endif

#define unlikely(x) (__builtin_expect((x),0))

// Tipo de ratio escolhido para fuzzy matching.
using CachedRatio = rapidfuzz::fuzz::RATIO_TYPE<std::string_view>;

extern "C" {
    #include "include/fuzz.h"

    static __attribute__((const, nothrow))
    /** Cache inicializado com ponteiros nulos. */
    FuzzCachedRatio fuzz_cached_null(void) {
        FuzzCachedRatio cached;
        cached.buffer = NULL;
        cached.buflen = 0;
        cached.block = NULL;
        return cached;
    }

    __attribute__((nonnull, leaf, nothrow))
    FuzzCachedRatio fuzz_cached_init(const char *str) {
        FuzzCachedRatio cache = fuzz_cached_null();

        // tamanho da string no cache
        cache.buflen = strlen(str);
        // aloca nova string e copia conteúdo
        cache.buffer = (char *) malloc(cache.buflen + 1);
        if unlikely(cache.buffer == NULL) {
            return fuzz_cached_null();
        }
        memcpy(cache.buffer, str, cache.buflen);
        cache.buffer[cache.buflen] = 0;

        // inicializa o cache no espaço reservado
        cache.block = new CachedRatio (
            std::string_view(cache.buffer, cache.buflen)
        );
        return cache;
    }

    __attribute__((pure, nonnull, leaf, nothrow))
    double fuzz_cached_ratio(const FuzzCachedRatio cached, const char *str, size_t len) {

        if unlikely(cached.buffer == NULL || cached.block == NULL) {
            return 1;
        }
        // usa o bloco do espaço reservado
        auto block = (const CachedRatio *) cached.block;
        // e calcula o score com em rapidfuz::CachedRatio::ratio
        double score = block->ratio(std::string_view(str, len));
        // adapta o valor
        return 1 - (score / 100);
    }

    __attribute__((nonnull, leaf, nothrow))
    void fuzz_cached_deinit(FuzzCachedRatio *cached) {
        // destrói o cache primeiro
        if unlikely(cached->block != NULL) {
            auto block = (CachedRatio *) cached->block;
            block->~CachedRatio();
            cached->block = NULL;
        }
        // então desaloca a string
        if unlikely(cached->buffer != NULL) {
            free(cached->buffer);
            cached->buffer = NULL;
            cached->buflen = 0;
        }
    }

    __attribute__((pure, nonnull, leaf, nothrow))
    double fuzz_levenshtein(const char *s1, size_t len1, const char *s2, size_t len2) {
        // só chama a função do rapidfuzz
        double score = rapidfuzz::string_metric::normalized_levenshtein(
            std::string_view(s1, len1), std::string_view(s2, len2)
        );
        // e adapta o valor
        return 1 - (score / 100);
    }
}
