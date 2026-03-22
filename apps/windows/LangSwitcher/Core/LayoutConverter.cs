using LangSwitcher.Helpers;

namespace LangSwitcher.Core;

/// <summary>
/// Ports CyrillicMapper.swift — maps Cyrillic ↔ QWERTY and validates via spell checker.
/// </summary>
public sealed class LayoutConverter
{
    private readonly SpellChecker _spell;

    public LayoutConverter(SpellChecker spell) => _spell = spell;

    public bool SpellCheckAvailable => _spell.IsAvailable;

    // ── Cyrillic → EN (ЙЦУКЕН + Ukrainian) ───────────────────────────────────

    private static readonly Dictionary<char, char> CyrillicToEn = new()
    {
        // Russian lowercase
        ['й']='q',['ц']='w',['у']='e',['к']='r',['е']='t',
        ['н']='y',['г']='u',['ш']='i',['щ']='o',['з']='p',
        ['х']='[',['ъ']=']',
        ['ф']='a',['ы']='s',['в']='d',['а']='f',['п']='g',
        ['р']='h',['о']='j',['л']='k',['д']='l',['ж']=';',
        ['э']='\'',
        ['я']='z',['ч']='x',['с']='c',['м']='v',['и']='b',
        ['т']='n',['ь']='m',['б']=',',['ю']='.',
        ['ё']='`',
        // Russian uppercase
        ['Й']='Q',['Ц']='W',['У']='E',['К']='R',['Е']='T',
        ['Н']='Y',['Г']='U',['Ш']='I',['Щ']='O',['З']='P',
        ['Х']='{',['Ъ']='}',
        ['Ф']='A',['Ы']='S',['В']='D',['А']='F',['П']='G',
        ['Р']='H',['О']='J',['Л']='K',['Д']='L',['Ж']=':',
        ['Э']='"',
        ['Я']='Z',['Ч']='X',['С']='C',['М']='V',['И']='B',
        ['Т']='N',['Ь']='M',['Б']='<',['Ю']='>',
        ['Ё']='~',
        // Ukrainian-specific lowercase
        ['і']='s',['ї']=']',['є']='\'',['ґ']='`',
        // Ukrainian-specific uppercase
        ['І']='S',['Ї']='}',['Є']='"',['Ґ']='~',
    };

    // ── EN → Cyrillic (with ambiguity for s/S) ────────────────────────────────

    private static readonly Dictionary<char, char[]> EnToCyrillicVariants = new()
    {
        ['q']=new[]{'й'},['w']=new[]{'ц'},['e']=new[]{'у'},['r']=new[]{'к'},['t']=new[]{'е'},
        ['y']=new[]{'н'},['u']=new[]{'г'},['i']=new[]{'ш'},['o']=new[]{'щ'},['p']=new[]{'з'},
        ['a']=new[]{'ф'},['s']=new[]{'ы','і'},['d']=new[]{'в'},['f']=new[]{'а'},['g']=new[]{'п'},
        ['h']=new[]{'р'},['j']=new[]{'о'},['k']=new[]{'л'},['l']=new[]{'д'},
        ['z']=new[]{'я'},['x']=new[]{'ч'},['c']=new[]{'с'},['v']=new[]{'м'},['b']=new[]{'и'},
        ['n']=new[]{'т'},['m']=new[]{'ь'},
        ['Q']=new[]{'Й'},['W']=new[]{'Ц'},['E']=new[]{'У'},['R']=new[]{'К'},['T']=new[]{'Е'},
        ['Y']=new[]{'Н'},['U']=new[]{'Г'},['I']=new[]{'Ш'},['O']=new[]{'Щ'},['P']=new[]{'З'},
        ['A']=new[]{'Ф'},['S']=new[]{'Ы','І'},['D']=new[]{'В'},['F']=new[]{'А'},['G']=new[]{'П'},
        ['H']=new[]{'Р'},['J']=new[]{'О'},['K']=new[]{'Л'},['L']=new[]{'Д'},
        ['Z']=new[]{'Я'},['X']=new[]{'Ч'},['C']=new[]{'С'},['V']=new[]{'М'},['B']=new[]{'И'},
        ['N']=new[]{'Т'},['M']=new[]{'Ь'},
        // Punctuation keys that produce Cyrillic on RU/UK layouts
        [',']=new[]{'б'},['<']=new[]{'Б'},
        ['.']=new[]{'ю'},['>']=new[]{'Ю'},
        [';']=new[]{'ж'},[':']=new[]{'Ж'},
        ['\'']=new[]{'э','є'},['"']=new[]{'Э','Є'},
        ['[']=new[]{'х'},['{']=new[]{'Х'},
        [']']=new[]{'ъ','ї'},['}']=new[]{'Ъ','Ї'},
        ['`']=new[]{'ё','ґ'},['~']=new[]{'Ё','Ґ'},
    };

    // Latin letters visually similar to Cyrillic
    private static readonly Dictionary<char, char> LatinToCyrillicLookalike = new()
    {
        ['A']='А',['a']='а',
        ['B']='В',
        ['C']='С',['c']='с',
        ['E']='Е',['e']='е',
        ['H']='Н',
        ['K']='К',['k']='к',
        ['M']='М',
        ['O']='О',['o']='о',
        ['P']='Р',['p']='р',
        ['T']='Т',
        ['X']='Х',['x']='х',
        ['Y']='У',['y']='у',
    };

    // ── Cyrillic detection ────────────────────────────────────────────────────

    public static bool IsCyrillic(string word)
    {
        if (string.IsNullOrEmpty(word)) return false;
        foreach (var ch in word)
            if (ch < 0x0400 || ch > 0x04FF) return false;
        return true;
    }

    // ── Convert Cyrillic → EN ─────────────────────────────────────────────────

    /// Returns null if any character has no mapping.
    public static string? ConvertCyrillicToEn(string word)
    {
        var sb = new System.Text.StringBuilder(word.Length);
        foreach (var ch in word)
        {
            if (!CyrillicToEn.TryGetValue(ch, out var mapped)) return null;
            sb.Append(mapped);
        }
        return sb.ToString();
    }

    /// Converts a word that may mix Cyrillic and Latin letters.
    /// Latin letters are preserved as-is. Returns null if nothing was converted.
    public static string? ConvertIncludingLatin(string word)
    {
        var sb = new System.Text.StringBuilder(word.Length);
        bool convertedAnyCyrillic = false;
        foreach (var ch in word)
        {
            if (CyrillicToEn.TryGetValue(ch, out var mapped))
            {
                sb.Append(mapped);
                convertedAnyCyrillic = true;
            }
            else if (ch < 128 && char.IsLetter(ch))
            {
                sb.Append(ch);
            }
            else return null;
        }
        return convertedAnyCyrillic ? sb.ToString() : null;
    }

    // ── Convert EN → Cyrillic via spell check ─────────────────────────────────

    public string? ConvertEnglishMistypeToValidCyrillic(string word)
    {
        if (string.IsNullOrEmpty(word)) return null;
        var candidates = BuildCyrillicCandidates(word);

        if (_spell.IsAvailable)
        {
            // Spell checker works: only accept a validated word
            foreach (var candidate in candidates)
                if (_spell.IsValidCyrillicWord(candidate))
                    return candidate;
            return null;
        }
        else
        {
            // No spell checker: return the first candidate only when there is no
            // mapping ambiguity (i.e. every character has exactly one Cyrillic option).
            // This avoids correcting real English words while still catching obvious
            // layout mistakes like "ghbdtn" → "привет".
            if (candidates.Count == 1)
                return candidates[0];
            return null;
        }
    }

    public string? CyrillicWordLanguage(string word) => _spell.CyrillicWordLanguage(word);

    // ── Spell-check wrappers ──────────────────────────────────────────────────

    public bool IsValidEnglishWord(string word)  => _spell.IsValidEnglishWord(word);
    public bool IsValidCyrillicWord(string word) => _spell.IsValidCyrillicWord(word);

    public bool IsValidCyrillicWordConsideringLatinOverlap(string word)
    {
        if (string.IsNullOrEmpty(word)) return false;
        if (IsCyrillic(word)) return _spell.IsValidCyrillicWord(word);

        var normalized = NormalizeLatinLookalikesToCyrillic(word);
        if (!IsCyrillic(normalized) || normalized == word) return false;
        return _spell.IsValidCyrillicWord(normalized);
    }

    // ── BFS candidate expansion ───────────────────────────────────────────────

    private const int MaxCandidates = 64;

    private static List<string> BuildCyrillicCandidates(string word)
    {
        var candidates = new List<string> { "" };
        foreach (var ch in word)
        {
            if (!EnToCyrillicVariants.TryGetValue(ch, out var variants))
                return new List<string>();

            var next = new List<string>();
            foreach (var prefix in candidates)
            {
                foreach (var v in variants)
                {
                    if (next.Count >= MaxCandidates) goto done;
                    next.Add(prefix + v);
                }
            }
            done:
            candidates = next;
            if (candidates.Count == 0) return candidates;
        }
        return candidates;
    }

    private static string NormalizeLatinLookalikesToCyrillic(string word)
    {
        var sb = new System.Text.StringBuilder(word.Length);
        foreach (var ch in word)
            sb.Append(LatinToCyrillicLookalike.TryGetValue(ch, out var cyr) ? cyr : ch);
        return sb.ToString();
    }
}
