#ifndef __FUZZ_H__
#define __FUZZ_H__

#include <stdint.h>
#include <stddef.h>

/**
 * Wrapper sobre o CachedRatio do rapidfuzz.
 */
typedef struct FuzzCachedRatio {
    // Buffer alocado no heap para controle da string.
    char *__restrict__ buffer;
    // Tamanho do buffer (e da string).
    size_t buflen;
    // Espaço para o CachedRatio.
    void *__restrict__ block;
} FuzzCachedRatio;

/**
 * Inicializa o CachedRatio.
 *
 * @param str pointeiro para a string.
 * @param len tamanho da string.
 *
 * @return String cacheada para comparações.
 */
FuzzCachedRatio fuzz_cached_init(const char *str)
__attribute__((nonnull, leaf, nothrow));

/**
 * Calcula um score entre a string cacheada e uma string dada.
 *
 * @param str pointeiro para a string a ser comparada.
 * @param len tamanho da string a ser comparada.
 *
 * @return Score entre 0 (match perfeito) e 1 (completamente diferentes).
 */
double fuzz_cached_ratio(const FuzzCachedRatio cached, const char *str, size_t len)
__attribute__((pure, nonnull, leaf, nothrow));

/**
 * Destrói a string e seu cache de comparação.
 *
 * @param cached string cacheada para comparações.
 */
void fuzz_cached_deinit(FuzzCachedRatio *cached)
__attribute__((nonnull, leaf, nothrow));

/**
 * Calcula a distância de Levenshtein normalizada.
 *
 * @see https://maxbachmann.github.io/RapidFuzz/string_metric.html#normalized-levenshtein
 */
double fuzz_levenshtein(const char *s1, size_t len1, const char *s2, size_t len2)
__attribute__((pure, nonnull, leaf, nothrow));

#endif // __FUZZ_H__
