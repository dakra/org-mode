;;; org-entities.el --- Support for Special Entities -*- lexical-binding: t; -*-

;; Copyright (C) 2010-2023 Free Software Foundation, Inc.

;; Author: Carsten Dominik <carsten.dominik@gmail.com>,
;;         Ulf Stegemann <ulf at zeitform dot de>
;; Keywords: outlines, calendar, wp
;; URL: https://orgmode.org
;;
;; This file is part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:

;;; Code:

(require 'org-macs)
(org-assert-version)

(declare-function org-mode "org" ())
(declare-function org-toggle-pretty-entities "org"       ())
(declare-function org-table-align            "org-table" ())

(defgroup org-entities nil
  "Options concerning entities in Org mode."
  :tag "Org Entities"
  :group 'org)

(defun org-entities--user-safe-p (v)
  "Non-nil if V is a safe value for `org-entities-user'."
  (pcase v
    (`nil t)
    (`(,(and (pred stringp)
	     (pred (string-match-p "\\`[a-zA-Z][a-zA-Z0-9]*\\'")))
       ,(pred stringp) ,(pred booleanp) ,(pred stringp)
       ,(pred stringp) ,(pred stringp) ,(pred stringp))
     t)
    (_ nil)))

(defcustom org-entities-user nil
  "User-defined entities used in Org to produce special characters.
Each entry in this list is a list of strings.  It associates the name
of the entity that can be inserted into an Org file as \\name with the
appropriate replacements for the different export backends.  The order
of the fields is the following

name                 As a string, without the leading backslash.
LaTeX replacement    In ready LaTeX, no further processing will take place.
LaTeX mathp          Either t or nil.  When t this entity needs to be in
                     math mode.
HTML replacement     In ready HTML, no further processing will take place.
                     Usually this will be an &...; entity.
ASCII replacement    Plain ASCII, no extensions.
Latin1 replacement   Use the special characters available in latin1.
utf-8 replacement    Use the special characters available in utf-8.

If you define new entities here that require specific LaTeX
packages to be loaded, add these packages to `org-latex-packages-alist'."
  :group 'org-entities
  :version "24.1"
  :type '(repeat
	  (list
	   (string :tag "name  ")
	   (string :tag "LaTeX ")
	   (boolean :tag "Require LaTeX math?")
	   (string :tag "HTML  ")
	   (string :tag "ASCII ")
	   (string :tag "Latin1")
	   (string :tag "utf-8 ")))
  :safe #'org-entities--user-safe-p)

(defconst org-entities
  (append
   '("* Letters"
     "** Latin"
     ("Agrave" "\\`{A}" nil "&Agrave;" "A" "??" "??")
     ("agrave" "\\`{a}" nil "&agrave;" "a" "??" "??")
     ("Aacute" "\\'{A}" nil "&Aacute;" "A" "??" "??")
     ("aacute" "\\'{a}" nil "&aacute;" "a" "??" "??")
     ("Acirc" "\\^{A}" nil "&Acirc;" "A" "??" "??")
     ("acirc" "\\^{a}" nil "&acirc;" "a" "??" "??")
     ("Amacr" "\\={A}" nil "&Amacr;" "A" "??" "??")
     ("amacr" "\\={a}" nil "&amacr;" "a" "??" "??")
     ("Atilde" "\\~{A}" nil "&Atilde;" "A" "??" "??")
     ("atilde" "\\~{a}" nil "&atilde;" "a" "??" "??")
     ("Auml" "\\\"{A}" nil "&Auml;" "Ae" "??" "??")
     ("auml" "\\\"{a}" nil "&auml;" "ae" "??" "??")
     ("Aring" "\\AA{}" nil "&Aring;" "A" "??" "??")
     ("AA" "\\AA{}" nil "&Aring;" "A" "??" "??")
     ("aring" "\\aa{}" nil "&aring;" "a" "??" "??")
     ("AElig" "\\AE{}" nil "&AElig;" "AE" "??" "??")
     ("aelig" "\\ae{}" nil "&aelig;" "ae" "??" "??")
     ("Ccedil" "\\c{C}" nil "&Ccedil;" "C" "??" "??")
     ("ccedil" "\\c{c}" nil "&ccedil;" "c" "??" "??")
     ("Egrave" "\\`{E}" nil "&Egrave;" "E" "??" "??")
     ("egrave" "\\`{e}" nil "&egrave;" "e" "??" "??")
     ("Eacute" "\\'{E}" nil "&Eacute;" "E" "??" "??")
     ("eacute" "\\'{e}" nil "&eacute;" "e" "??" "??")
     ("Ecirc" "\\^{E}" nil "&Ecirc;" "E" "??" "??")
     ("ecirc" "\\^{e}" nil "&ecirc;" "e" "??" "??")
     ("Euml" "\\\"{E}" nil "&Euml;" "E" "??" "??")
     ("euml" "\\\"{e}" nil "&euml;" "e" "??" "??")
     ("Igrave" "\\`{I}" nil "&Igrave;" "I" "??" "??")
     ("igrave" "\\`{i}" nil "&igrave;" "i" "??" "??")
     ("Iacute" "\\'{I}" nil "&Iacute;" "I" "??" "??")
     ("iacute" "\\'{i}" nil "&iacute;" "i" "??" "??")
     ("Idot" "\\.{I}" nil "&idot;" "I" "??" "??")
     ("inodot" "\\i" nil "&inodot;" "i" "??" "??")
     ("Icirc" "\\^{I}" nil "&Icirc;" "I" "??" "??")
     ("icirc" "\\^{i}" nil "&icirc;" "i" "??" "??")
     ("Iuml" "\\\"{I}" nil "&Iuml;" "I" "??" "??")
     ("iuml" "\\\"{i}" nil "&iuml;" "i" "??" "??")
     ("Ntilde" "\\~{N}" nil "&Ntilde;" "N" "??" "??")
     ("ntilde" "\\~{n}" nil "&ntilde;" "n" "??" "??")
     ("Ograve" "\\`{O}" nil "&Ograve;" "O" "??" "??")
     ("ograve" "\\`{o}" nil "&ograve;" "o" "??" "??")
     ("Oacute" "\\'{O}" nil "&Oacute;" "O" "??" "??")
     ("oacute" "\\'{o}" nil "&oacute;" "o" "??" "??")
     ("Ocirc" "\\^{O}" nil "&Ocirc;" "O" "??" "??")
     ("ocirc" "\\^{o}" nil "&ocirc;" "o" "??" "??")
     ("Otilde" "\\~{O}" nil "&Otilde;" "O" "??" "??")
     ("otilde" "\\~{o}" nil "&otilde;" "o" "??" "??")
     ("Ouml" "\\\"{O}" nil "&Ouml;" "Oe" "??" "??")
     ("ouml" "\\\"{o}" nil "&ouml;" "oe" "??" "??")
     ("Oslash" "\\O" nil "&Oslash;" "O" "??" "??")
     ("oslash" "\\o{}" nil "&oslash;" "o" "??" "??")
     ("OElig" "\\OE{}" nil "&OElig;" "OE" "OE" "??")
     ("oelig" "\\oe{}" nil "&oelig;" "oe" "oe" "??")
     ("Scaron" "\\v{S}" nil "&Scaron;" "S" "S" "??")
     ("scaron" "\\v{s}" nil "&scaron;" "s" "s" "??")
     ("szlig" "\\ss{}" nil "&szlig;" "ss" "??" "??")
     ("Ugrave" "\\`{U}" nil "&Ugrave;" "U" "??" "??")
     ("ugrave" "\\`{u}" nil "&ugrave;" "u" "??" "??")
     ("Uacute" "\\'{U}" nil "&Uacute;" "U" "??" "??")
     ("uacute" "\\'{u}" nil "&uacute;" "u" "??" "??")
     ("Ucirc" "\\^{U}" nil "&Ucirc;" "U" "??" "??")
     ("ucirc" "\\^{u}" nil "&ucirc;" "u" "??" "??")
     ("Uuml" "\\\"{U}" nil "&Uuml;" "Ue" "??" "??")
     ("uuml" "\\\"{u}" nil "&uuml;" "ue" "??" "??")
     ("Yacute" "\\'{Y}" nil "&Yacute;" "Y" "??" "??")
     ("yacute" "\\'{y}" nil "&yacute;" "y" "??" "??")
     ("Yuml" "\\\"{Y}" nil "&Yuml;" "Y" "Y" "??")
     ("yuml" "\\\"{y}" nil "&yuml;" "y" "??" "??")

     "** Latin (special face)"
     ("fnof" "\\textit{f}" nil "&fnof;" "f" "f" "??")
     ("real" "\\Re" t "&real;" "R" "R" "???")
     ("image" "\\Im" t "&image;" "I" "I" "???")
     ("weierp" "\\wp" t "&weierp;" "P" "P" "???")
     ("ell" "\\ell" t "&ell;" "ell" "ell" "???")
     ("imath" "\\imath" t "&imath;" "[dotless i]" "dotless i" "??")
     ("jmath" "\\jmath" t "&jmath;" "[dotless j]" "dotless j" "??")

     "** Greek"
     ("Alpha" "A" nil "&Alpha;" "Alpha" "Alpha" "??")
     ("alpha" "\\alpha" t "&alpha;" "alpha" "alpha" "??")
     ("Beta" "B" nil "&Beta;" "Beta" "Beta" "??")
     ("beta" "\\beta" t "&beta;" "beta" "beta" "??")
     ("Gamma" "\\Gamma" t "&Gamma;" "Gamma" "Gamma" "??")
     ("gamma" "\\gamma" t "&gamma;" "gamma" "gamma" "??")
     ("Delta" "\\Delta" t "&Delta;" "Delta" "Delta" "??")
     ("delta" "\\delta" t "&delta;" "delta" "delta" "??")
     ("Epsilon" "E" nil "&Epsilon;" "Epsilon" "Epsilon" "??")
     ("epsilon" "\\epsilon" t "&epsilon;" "epsilon" "epsilon" "??")
     ("varepsilon" "\\varepsilon" t "&epsilon;" "varepsilon" "varepsilon" "??")
     ("Zeta" "Z" nil "&Zeta;" "Zeta" "Zeta" "??")
     ("zeta" "\\zeta" t "&zeta;" "zeta" "zeta" "??")
     ("Eta" "H" nil "&Eta;" "Eta" "Eta" "??")
     ("eta" "\\eta" t "&eta;" "eta" "eta" "??")
     ("Theta" "\\Theta" t "&Theta;" "Theta" "Theta" "??")
     ("theta" "\\theta" t "&theta;" "theta" "theta" "??")
     ("thetasym" "\\vartheta" t "&thetasym;" "theta" "theta" "??")
     ("vartheta" "\\vartheta" t "&thetasym;" "theta" "theta" "??")
     ("Iota" "I" nil "&Iota;" "Iota" "Iota" "??")
     ("iota" "\\iota" t "&iota;" "iota" "iota" "??")
     ("Kappa" "K" nil "&Kappa;" "Kappa" "Kappa" "??")
     ("kappa" "\\kappa" t "&kappa;" "kappa" "kappa" "??")
     ("Lambda" "\\Lambda" t "&Lambda;" "Lambda" "Lambda" "??")
     ("lambda" "\\lambda" t "&lambda;" "lambda" "lambda" "??")
     ("Mu" "M" nil "&Mu;" "Mu" "Mu" "??")
     ("mu" "\\mu" t "&mu;" "mu" "mu" "??")
     ("nu" "\\nu" t "&nu;" "nu" "nu" "??")
     ("Nu" "N" nil "&Nu;" "Nu" "Nu" "??")
     ("Xi" "\\Xi" t "&Xi;" "Xi" "Xi" "??")
     ("xi" "\\xi" t "&xi;" "xi" "xi" "??")
     ("Omicron" "O" nil "&Omicron;" "Omicron" "Omicron" "??")
     ("omicron" "\\textit{o}" nil "&omicron;" "omicron" "omicron" "??")
     ("Pi" "\\Pi" t "&Pi;" "Pi" "Pi" "??")
     ("pi" "\\pi" t "&pi;" "pi" "pi" "??")
     ("Rho" "P" nil "&Rho;" "Rho" "Rho" "??")
     ("rho" "\\rho" t "&rho;" "rho" "rho" "??")
     ("Sigma" "\\Sigma" t "&Sigma;" "Sigma" "Sigma" "??")
     ("sigma" "\\sigma" t "&sigma;" "sigma" "sigma" "??")
     ("sigmaf" "\\varsigma" t "&sigmaf;" "sigmaf" "sigmaf" "??")
     ("varsigma" "\\varsigma" t "&sigmaf;" "varsigma" "varsigma" "??")
     ("Tau" "T" nil "&Tau;" "Tau" "Tau" "??")
     ("Upsilon" "\\Upsilon" t "&Upsilon;" "Upsilon" "Upsilon" "??")
     ("upsih" "\\Upsilon" t "&upsih;" "upsilon" "upsilon" "??")
     ("upsilon" "\\upsilon" t "&upsilon;" "upsilon" "upsilon" "??")
     ("Phi" "\\Phi" t "&Phi;" "Phi" "Phi" "??")
     ("phi" "\\phi" t "&phi;" "phi" "phi" "??")
     ("varphi" "\\varphi" t "&varphi;" "varphi" "varphi" "??")
     ("Chi" "X" nil "&Chi;" "Chi" "Chi" "??")
     ("chi" "\\chi" t "&chi;" "chi" "chi" "??")
     ("acutex" "\\acute x" t "&acute;x" "'x" "'x" "??????")
     ("Psi" "\\Psi" t "&Psi;" "Psi" "Psi" "??")
     ("psi" "\\psi" t "&psi;" "psi" "psi" "??")
     ("tau" "\\tau" t "&tau;" "tau" "tau" "??")
     ("Omega" "\\Omega" t "&Omega;" "Omega" "Omega" "??")
     ("omega" "\\omega" t "&omega;" "omega" "omega" "??")
     ("piv" "\\varpi" t "&piv;" "omega-pi" "omega-pi" "??")
     ("varpi" "\\varpi" t "&piv;" "omega-pi" "omega-pi" "??")
     ("partial" "\\partial" t "&part;" "[partial differential]" "[partial differential]" "???")

     "** Hebrew"
     ("alefsym" "\\aleph" t "&alefsym;" "aleph" "aleph" "???")
     ("aleph" "\\aleph" t "&aleph;" "aleph" "aleph" "???")
     ("gimel" "\\gimel" t "&gimel;" "gimel" "gimel" "???")
     ("beth" "\\beth" t "&beth;" "beth" "beth" "??")
     ("dalet" "\\daleth" t "&daleth;" "dalet" "dalet" "??")

     "** Icelandic"
     ("ETH" "\\DH{}" nil "&ETH;" "D" "??" "??")
     ("eth" "\\dh{}" nil "&eth;" "dh" "??" "??")
     ("THORN" "\\TH{}" nil "&THORN;" "TH" "??" "??")
     ("thorn" "\\th{}" nil "&thorn;" "th" "??" "??")

     "* Punctuation"
     "** Dots and Marks"
     ("dots" "\\dots{}" nil "&hellip;" "..." "..." "???")
     ("cdots" "\\cdots{}" t "&ctdot;" "..." "..." "???")
     ("hellip" "\\dots{}" nil "&hellip;" "..." "..." "???")
     ("middot" "\\textperiodcentered{}" nil "&middot;" "." "??" "??")
     ("iexcl" "!`" nil "&iexcl;" "!" "??" "??")
     ("iquest" "?`" nil "&iquest;" "?" "??" "??")

     "** Dash-like"
     ("shy" "\\-" nil "&shy;" "" "" "")
     ("ndash" "--" nil "&ndash;" "-" "-" "???")
     ("mdash" "---" nil "&mdash;" "--" "--" "???")

     "** Quotations"
     ("quot" "\\textquotedbl{}" nil "&quot;" "\"" "\"" "\"")
     ("acute" "\\textasciiacute{}" nil "&acute;" "'" "??" "??")
     ("ldquo" "\\textquotedblleft{}" nil "&ldquo;" "\"" "\"" "???")
     ("rdquo" "\\textquotedblright{}" nil "&rdquo;" "\"" "\"" "???")
     ("bdquo" "\\quotedblbase{}" nil "&bdquo;" "\"" "\"" "???")
     ("lsquo" "\\textquoteleft{}" nil "&lsquo;" "`" "`" "???")
     ("rsquo" "\\textquoteright{}" nil "&rsquo;" "'" "'" "???")
     ("sbquo" "\\quotesinglbase{}" nil "&sbquo;" "," "," "???")
     ("laquo" "\\guillemotleft{}" nil "&laquo;" "<<" "??" "??")
     ("raquo" "\\guillemotright{}" nil "&raquo;" ">>" "??" "??")
     ("lsaquo" "\\guilsinglleft{}" nil "&lsaquo;" "<" "<" "???")
     ("rsaquo" "\\guilsinglright{}" nil "&rsaquo;" ">" ">" "???")

     "* Other"
     "** Misc. (often used)"
     ("circ" "\\^{}" nil "&circ;" "^" "^" "???")
     ("vert" "\\vert{}" t "&vert;" "|" "|" "|")
     ("vbar" "|" nil "|" "|" "|" "|")
     ("brvbar" "\\textbrokenbar{}" nil "&brvbar;" "|" "??" "??")
     ("S" "\\S" nil "&sect;" "paragraph" "??" "??")
     ("sect" "\\S" nil "&sect;" "paragraph" "??" "??")
     ("amp" "\\&" nil "&amp;" "&" "&" "&")
     ("lt" "\\textless{}" nil "&lt;" "<" "<" "<")
     ("gt" "\\textgreater{}" nil "&gt;" ">" ">" ">")
     ("tilde" "\\textasciitilde{}" nil "~" "~" "~" "~")
     ("slash" "/" nil "/" "/" "/" "/")
     ("plus" "+" nil "+" "+" "+" "+")
     ("under" "\\_" nil "_" "_" "_" "_")
     ("equal" "=" nil "=" "=" "=" "=")
     ("asciicirc" "\\textasciicircum{}" nil "^" "^" "^" "^")
     ("dagger" "\\textdagger{}" nil "&dagger;" "[dagger]" "[dagger]" "???")
     ("dag" "\\dag{}" nil "&dagger;" "[dagger]" "[dagger]" "???")
     ("Dagger" "\\textdaggerdbl{}" nil "&Dagger;" "[doubledagger]" "[doubledagger]" "???")
     ("ddag" "\\ddag{}" nil "&Dagger;" "[doubledagger]" "[doubledagger]" "???")

     "** Whitespace"
     ("nbsp" "~" nil "&nbsp;" " " "\x00A0" "\x00A0")
     ("ensp" "\\hspace*{.5em}" nil "&ensp;" " " " " "???")
     ("emsp" "\\hspace*{1em}" nil "&emsp;" " " " " "???")
     ("thinsp" "\\hspace*{.2em}" nil "&thinsp;" " " " " "???")

     "** Currency"
     ("curren" "\\textcurrency{}" nil "&curren;" "curr." "??" "??")
     ("cent" "\\textcent{}" nil "&cent;" "cent" "??" "??")
     ("pound" "\\pounds{}" nil "&pound;" "pound" "??" "??")
     ("yen" "\\textyen{}" nil "&yen;" "yen" "??" "??")
     ("euro" "\\texteuro{}" nil "&euro;" "EUR" "EUR" "???")
     ("EUR" "\\texteuro{}" nil "&euro;" "EUR" "EUR" "???")
     ("dollar" "\\$" nil "$" "$" "$" "$")
     ("USD" "\\$" nil "$" "$" "$" "$")

     "** Property Marks"
     ("copy" "\\textcopyright{}" nil "&copy;" "(c)" "??" "??")
     ("reg" "\\textregistered{}" nil "&reg;" "(r)" "??" "??")
     ("trade" "\\texttrademark{}" nil "&trade;" "TM" "TM" "???")

     "** Science et al."
     ("minus" "-" t "&minus;" "-" "-" "???")
     ("pm" "\\textpm{}" nil "&plusmn;" "+-" "??" "??")
     ("plusmn" "\\textpm{}" nil "&plusmn;" "+-" "??" "??")
     ("times" "\\texttimes{}" nil "&times;" "*" "??" "??")
     ("frasl" "/" nil "&frasl;" "/" "/" "???")
     ("colon" "\\colon" t ":" ":" ":" ":")
     ("div" "\\textdiv{}" nil "&divide;" "/" "??" "??")
     ("frac12" "\\textonehalf{}" nil "&frac12;" "1/2" "??" "??")
     ("frac14" "\\textonequarter{}" nil "&frac14;" "1/4" "??" "??")
     ("frac34" "\\textthreequarters{}" nil "&frac34;" "3/4" "??" "??")
     ("permil" "\\textperthousand{}" nil "&permil;" "per thousand" "per thousand" "???")
     ("sup1" "\\textonesuperior{}" nil "&sup1;" "^1" "??" "??")
     ("sup2" "\\texttwosuperior{}" nil "&sup2;" "^2" "??" "??")
     ("sup3" "\\textthreesuperior{}" nil "&sup3;" "^3" "??" "??")
     ("radic" "\\sqrt{\\,}" t "&radic;" "[square root]" "[square root]" "???")
     ("sum" "\\sum" t "&sum;" "[sum]" "[sum]" "???")
     ("prod" "\\prod" t "&prod;" "[product]" "[n-ary product]" "???")
     ("micro" "\\textmu{}" nil "&micro;" "micro" "??" "??")
     ("macr" "\\textasciimacron{}" nil "&macr;" "[macron]" "??" "??")
     ("deg" "\\textdegree{}" nil "&deg;" "degree" "??" "??")
     ("prime" "\\prime" t "&prime;" "'" "'" "???")
     ("Prime" "\\prime{}\\prime" t "&Prime;" "''" "''" "???")
     ("infin" "\\infty" t "&infin;" "[infinity]" "[infinity]" "???")
     ("infty" "\\infty" t "&infin;" "[infinity]" "[infinity]" "???")
     ("prop" "\\propto" t "&prop;" "[proportional to]" "[proportional to]" "???")
     ("propto" "\\propto" t "&prop;" "[proportional to]" "[proportional to]" "???")
     ("not" "\\textlnot{}" nil "&not;" "[angled dash]" "??" "??")
     ("neg" "\\neg{}" t "&not;" "[angled dash]" "??" "??")
     ("land" "\\land" t "&and;" "[logical and]" "[logical and]" "???")
     ("wedge" "\\wedge" t "&and;" "[logical and]" "[logical and]" "???")
     ("lor" "\\lor" t "&or;" "[logical or]" "[logical or]" "???")
     ("vee" "\\vee" t "&or;" "[logical or]" "[logical or]" "???")
     ("cap" "\\cap" t "&cap;" "[intersection]" "[intersection]" "???")
     ("cup" "\\cup" t "&cup;" "[union]" "[union]" "???")
     ("smile" "\\smile" t "&smile;" "[cup product]" "[cup product]" "???")
     ("frown" "\\frown" t "&frown;" "[Cap product]" "[cap product]" "???")
     ("int" "\\int" t "&int;" "[integral]" "[integral]" "???")
     ("therefore" "\\therefore" t "&there4;" "[therefore]" "[therefore]" "???")
     ("there4" "\\therefore" t "&there4;" "[therefore]" "[therefore]" "???")
     ("because" "\\because" t "&because;" "[because]" "[because]" "???")
     ("sim" "\\sim" t "&sim;" "~" "~" "???")
     ("cong" "\\cong" t "&cong;" "[approx. equal to]" "[approx. equal to]" "???")
     ("simeq" "\\simeq" t "&cong;"  "[approx. equal to]" "[approx. equal to]" "???")
     ("asymp" "\\asymp" t "&asymp;" "[almost equal to]" "[almost equal to]" "???")
     ("approx" "\\approx" t "&asymp;" "[almost equal to]" "[almost equal to]" "???")
     ("ne" "\\ne" t "&ne;" "[not equal to]" "[not equal to]" "???")
     ("neq" "\\neq" t "&ne;" "[not equal to]" "[not equal to]" "???")
     ("equiv" "\\equiv" t "&equiv;" "[identical to]" "[identical to]" "???")

     ("triangleq" "\\triangleq" t "&triangleq;" "[defined to]" "[defined to]" "???")
     ("le" "\\le" t "&le;" "<=" "<=" "???")
     ("leq" "\\le" t "&le;" "<=" "<=" "???")
     ("ge" "\\ge" t "&ge;" ">=" ">=" "???")
     ("geq" "\\ge" t "&ge;" ">=" ">=" "???")
     ("lessgtr" "\\lessgtr" t "&lessgtr;" "[less than or greater than]" "[less than or greater than]" "???")
     ("lesseqgtr" "\\lesseqgtr" t "&lesseqgtr;" "[less than or equal or greater than or equal]" "[less than or equal or greater than or equal]" "???")
     ("ll" "\\ll" t  "&Lt;" "<<" "<<" "???")
     ("Ll" "\\lll" t "&Ll;" "<<<" "<<<" "???")
     ("lll" "\\lll" t "&Ll;" "<<<" "<<<" "???")
     ("gg" "\\gg" t  "&Gt;" ">>" ">>" "???")
     ("Gg" "\\ggg" t "&Gg;" ">>>" ">>>" "???")
     ("ggg" "\\ggg" t "&Gg;" ">>>" ">>>" "???")
     ("prec" "\\prec" t "&pr;" "[precedes]" "[precedes]" "???")
     ("preceq" "\\preceq" t "&prcue;" "[precedes or equal]" "[precedes or equal]" "???")
     ("preccurlyeq" "\\preccurlyeq" t "&prcue;" "[precedes or equal]" "[precedes or equal]" "???")
     ("succ" "\\succ" t "&sc;" "[succeeds]" "[succeeds]" "???")
     ("succeq" "\\succeq" t "&sccue;" "[succeeds or equal]" "[succeeds or equal]" "???")
     ("succcurlyeq" "\\succcurlyeq" t "&sccue;" "[succeeds or equal]" "[succeeds or equal]" "???")
     ("sub" "\\subset" t "&sub;" "[subset of]" "[subset of]" "???")
     ("subset" "\\subset" t "&sub;" "[subset of]" "[subset of]" "???")
     ("sup" "\\supset" t "&sup;" "[superset of]" "[superset of]" "???")
     ("supset" "\\supset" t "&sup;" "[superset of]" "[superset of]" "???")
     ("nsub" "\\not\\subset" t "&nsub;" "[not a subset of]" "[not a subset of" "???")
     ("sube" "\\subseteq" t "&sube;" "[subset of or equal to]" "[subset of or equal to]" "???")
     ("nsup" "\\not\\supset" t "&nsup;" "[not a superset of]" "[not a superset of]" "???")
     ("supe" "\\supseteq" t "&supe;" "[superset of or equal to]" "[superset of or equal to]" "???")
     ("setminus" "\\setminus" t "&setminus;" "\" "\" "???")
     ("forall" "\\forall" t "&forall;" "[for all]" "[for all]" "???")
     ("exist" "\\exists" t "&exist;" "[there exists]" "[there exists]" "???")
     ("exists" "\\exists" t "&exist;" "[there exists]" "[there exists]" "???")
     ("nexist" "\\nexists" t "&exist;" "[there does not exists]" "[there does not  exists]" "???")
     ("nexists" "\\nexists" t "&exist;" "[there does not exists]" "[there does not  exists]" "???")
     ("empty" "\\emptyset" t "&empty;" "[empty set]" "[empty set]" "???")
     ("emptyset" "\\emptyset" t "&empty;" "[empty set]" "[empty set]" "???")
     ("isin" "\\in" t "&isin;" "[element of]" "[element of]" "???")
     ("in" "\\in" t "&isin;" "[element of]" "[element of]" "???")
     ("notin" "\\notin" t "&notin;" "[not an element of]" "[not an element of]" "???")
     ("ni" "\\ni" t "&ni;" "[contains as member]" "[contains as member]" "???")
     ("nabla" "\\nabla" t "&nabla;" "[nabla]" "[nabla]" "???")
     ("ang" "\\angle" t "&ang;" "[angle]" "[angle]" "???")
     ("angle" "\\angle" t "&ang;" "[angle]" "[angle]" "???")
     ("perp" "\\perp" t "&perp;" "[up tack]" "[up tack]" "???")
     ("parallel" "\\parallel" t "&parallel;" "||" "||" "???")
     ("sdot" "\\cdot" t "&sdot;" "[dot]" "[dot]" "???")
     ("cdot" "\\cdot" t "&sdot;" "[dot]" "[dot]" "???")
     ("lceil" "\\lceil" t "&lceil;" "[left ceiling]" "[left ceiling]" "???")
     ("rceil" "\\rceil" t "&rceil;" "[right ceiling]" "[right ceiling]" "???")
     ("lfloor" "\\lfloor" t "&lfloor;" "[left floor]" "[left floor]" "???")
     ("rfloor" "\\rfloor" t "&rfloor;" "[right floor]" "[right floor]" "???")
     ("lang" "\\langle" t "&lang;" "<" "<" "???")
     ("rang" "\\rangle" t "&rang;" ">" ">" "???")
     ("langle" "\\langle" t "&lang;" "<" "<" "???")
     ("rangle" "\\rangle" t "&rang;" ">" ">" "???")
     ("hbar" "\\hbar" t "&hbar;" "hbar" "hbar" "???")
     ("mho" "\\mho" t "&mho;" "mho" "mho" "???")

     "** Arrows"
     ("larr" "\\leftarrow" t "&larr;" "<-" "<-" "???")
     ("leftarrow" "\\leftarrow" t "&larr;"  "<-" "<-" "???")
     ("gets" "\\gets" t "&larr;"  "<-" "<-" "???")
     ("lArr" "\\Leftarrow" t "&lArr;" "<=" "<=" "???")
     ("Leftarrow" "\\Leftarrow" t "&lArr;" "<=" "<=" "???")
     ("uarr" "\\uparrow" t "&uarr;" "[uparrow]" "[uparrow]" "???")
     ("uparrow" "\\uparrow" t "&uarr;" "[uparrow]" "[uparrow]" "???")
     ("uArr" "\\Uparrow" t "&uArr;" "[dbluparrow]" "[dbluparrow]" "???")
     ("Uparrow" "\\Uparrow" t "&uArr;" "[dbluparrow]" "[dbluparrow]" "???")
     ("rarr" "\\rightarrow" t "&rarr;" "->" "->" "???")
     ("to" "\\to" t "&rarr;" "->" "->" "???")
     ("rightarrow" "\\rightarrow" t "&rarr;"  "->" "->" "???")
     ("rArr" "\\Rightarrow" t "&rArr;" "=>" "=>" "???")
     ("Rightarrow" "\\Rightarrow" t "&rArr;" "=>" "=>" "???")
     ("darr" "\\downarrow" t "&darr;" "[downarrow]" "[downarrow]" "???")
     ("downarrow" "\\downarrow" t "&darr;" "[downarrow]" "[downarrow]" "???")
     ("dArr" "\\Downarrow" t "&dArr;" "[dbldownarrow]" "[dbldownarrow]" "???")
     ("Downarrow" "\\Downarrow" t "&dArr;" "[dbldownarrow]" "[dbldownarrow]" "???")
     ("harr" "\\leftrightarrow" t "&harr;" "<->" "<->" "???")
     ("leftrightarrow" "\\leftrightarrow" t "&harr;"  "<->" "<->" "???")
     ("hArr" "\\Leftrightarrow" t "&hArr;" "<=>" "<=>" "???")
     ("Leftrightarrow" "\\Leftrightarrow" t "&hArr;" "<=>" "<=>" "???")
     ("crarr" "\\hookleftarrow" t "&crarr;" "<-'" "<-'" "???")
     ("hookleftarrow" "\\hookleftarrow" t "&crarr;"  "<-'" "<-'" "???")

     "** Function names"
     ("arccos" "\\arccos" t "arccos" "arccos" "arccos" "arccos")
     ("arcsin" "\\arcsin" t "arcsin" "arcsin" "arcsin" "arcsin")
     ("arctan" "\\arctan" t "arctan" "arctan" "arctan" "arctan")
     ("arg" "\\arg" t "arg" "arg" "arg" "arg")
     ("cos" "\\cos" t "cos" "cos" "cos" "cos")
     ("cosh" "\\cosh" t "cosh" "cosh" "cosh" "cosh")
     ("cot" "\\cot" t "cot" "cot" "cot" "cot")
     ("coth" "\\coth" t "coth" "coth" "coth" "coth")
     ("csc" "\\csc" t "csc" "csc" "csc" "csc")
     ("deg" "\\deg" t "&deg;" "deg" "deg" "deg")
     ("det" "\\det" t "det" "det" "det" "det")
     ("dim" "\\dim" t "dim" "dim" "dim" "dim")
     ("exp" "\\exp" t "exp" "exp" "exp" "exp")
     ("gcd" "\\gcd" t "gcd" "gcd" "gcd" "gcd")
     ("hom" "\\hom" t "hom" "hom" "hom" "hom")
     ("inf" "\\inf" t "inf" "inf" "inf" "inf")
     ("ker" "\\ker" t "ker" "ker" "ker" "ker")
     ("lg" "\\lg" t "lg" "lg" "lg" "lg")
     ("lim" "\\lim" t "lim" "lim" "lim" "lim")
     ("liminf" "\\liminf" t "liminf" "liminf" "liminf" "liminf")
     ("limsup" "\\limsup" t "limsup" "limsup" "limsup" "limsup")
     ("ln" "\\ln" t "ln" "ln" "ln" "ln")
     ("log" "\\log" t "log" "log" "log" "log")
     ("max" "\\max" t "max" "max" "max" "max")
     ("min" "\\min" t "min" "min" "min" "min")
     ("Pr" "\\Pr" t "Pr" "Pr" "Pr" "Pr")
     ("sec" "\\sec" t "sec" "sec" "sec" "sec")
     ("sin" "\\sin" t "sin" "sin" "sin" "sin")
     ("sinh" "\\sinh" t "sinh" "sinh" "sinh" "sinh")
     ("sup" "\\sup" t "&sup;" "sup" "sup" "sup")
     ("tan" "\\tan" t "tan" "tan" "tan" "tan")
     ("tanh" "\\tanh" t "tanh" "tanh" "tanh" "tanh")

     "** Signs & Symbols"
     ("bull" "\\textbullet{}" nil "&bull;" "*" "*" "???")
     ("bullet" "\\textbullet{}" nil "&bull;" "*" "*" "???")
     ("star" "\\star" t "*" "*" "*" "???")
     ("lowast" "\\ast" t "&lowast;" "*" "*" "???")
     ("ast" "\\ast" t "&lowast;" "*" "*" "*")
     ("odot" "\\odot" t "o" "[circled dot]" "[circled dot]" "??")
     ("oplus" "\\oplus" t "&oplus;" "[circled plus]" "[circled plus]" "???")
     ("otimes" "\\otimes" t "&otimes;" "[circled times]" "[circled times]" "???")
     ("check" "\\checkmark" t "&checkmark;" "[checkmark]" "[checkmark]" "???")
     ("checkmark" "\\checkmark" t "&check;" "[checkmark]" "[checkmark]" "???")

     "** Miscellaneous (seldom used)"
     ("para" "\\P{}" nil "&para;" "[pilcrow]" "??" "??")
     ("ordf" "\\textordfeminine{}" nil "&ordf;" "_a_" "??" "??")
     ("ordm" "\\textordmasculine{}" nil "&ordm;" "_o_" "??" "??")
     ("cedil" "\\c{}" nil "&cedil;" "[cedilla]" "??" "??")
     ("oline" "\\overline{~}" t "&oline;" "[overline]" "??" "???")
     ("uml" "\\textasciidieresis{}" nil "&uml;" "[diaeresis]" "??" "??")
     ("zwnj" "\\/{}" nil "&zwnj;" "" "" "???")
     ("zwj" "" nil "&zwj;" "" "" "???")
     ("lrm" "" nil "&lrm;" "" "" "???")
     ("rlm" "" nil "&rlm;" "" "" "???")

     "** Smilies"
     ("smiley" "\\ddot\\smile" t "&#9786;" ":-)" ":-)" "???")
     ("blacksmile" "\\ddot\\smile" t "&#9787;" ":-)" ":-)" "???")
     ("sad" "\\ddot\\frown" t "&#9785;" ":-(" ":-(" "???")
     ("frowny" "\\ddot\\frown" t "&#9785;" ":-(" ":-(" "???")

     "** Suits"
     ("clubs" "\\clubsuit" t "&clubs;" "[clubs]" "[clubs]" "???")
     ("clubsuit" "\\clubsuit" t "&clubs;" "[clubs]" "[clubs]" "???")
     ("spades" "\\spadesuit" t "&spades;" "[spades]" "[spades]" "???")
     ("spadesuit" "\\spadesuit" t "&spades;" "[spades]" "[spades]" "???")
     ("hearts" "\\heartsuit" t "&hearts;" "[hearts]" "[hearts]" "???")
     ("heartsuit" "\\heartsuit" t "&heartsuit;" "[hearts]" "[hearts]" "???")
     ("diams" "\\diamondsuit" t "&diams;" "[diamonds]" "[diamonds]" "???")
     ("diamondsuit" "\\diamondsuit" t "&diams;" "[diamonds]" "[diamonds]" "???")
     ("diamond" "\\diamondsuit" t "&diamond;" "[diamond]" "[diamond]" "???")
     ("Diamond" "\\diamondsuit" t "&diamond;" "[diamond]" "[diamond]" "???")
     ("loz" "\\lozenge" t "&loz;" "[lozenge]" "[lozenge]" "???"))
   ;; Add "\_ "-entity family for spaces.
   (let (space-entities html-spaces (entity "_"))
     (dolist (n (number-sequence 1 20) (nreverse space-entities))
       (let ((spaces (make-string n ?\s)))
	 (push (list (setq entity (concat entity " "))
		     (format "\\hspace*{%sem}" (* n .5))
		     nil
		     (setq html-spaces (concat "&ensp;" html-spaces))
		     spaces
		     spaces
		     (make-string n ?\x2002))
	       space-entities)))))
  "Default entities used in Org mode to produce special characters.
For details see `org-entities-user'.")

(defsubst org-entity-get (name)
  "Get the proper association for NAME from the entity lists.
This first checks the user list, then the built-in list."
  (or (assoc name org-entities-user)
      (assoc name org-entities)))

;; Helpfunctions to create a table for orgmode.org/worg/org-symbols.org

(defun org-entities-create-table ()
  "Create an Org mode table with all entities."
  (interactive)
  (let ((pos (point)))
    (insert "|Name|LaTeX code|LaTeX|HTML code |HTML|ASCII|Latin1|UTF-8\n|-\n")
    (dolist (e org-entities)
      (pcase e
	(`(,name ,latex ,mathp ,html ,ascii ,latin ,utf8)
	 (when (equal ascii "|") (setq ascii "\\vert"))
	 (when (equal latin "|") (setq latin "\\vert"))
	 (when (equal utf8  "|") (setq utf8  "\\vert"))
	 (when (equal ascii "=>") (setq ascii "= >"))
	 (when (equal latin "=>") (setq latin "= >"))
	 (insert "|" name
		 "|" (format "=%s=" latex)
		 "|" (format (if mathp "$%s$" "$\\mbox{%s}$") latex)
		 "|" (format "=%s=" html) "|" html
		 "|" ascii "|" latin "|" utf8
		 "|\n"))))
    (goto-char pos)
    (org-table-align)))

(defvar org-pretty-entities) ;; declare defcustom from org
(defun org-entities-help ()
  "Create a Help buffer with all available entities."
  (interactive)
  (with-output-to-temp-buffer "*Org Entity Help*"
    (princ "Org mode entities\n=================\n\n")
    (let ((ll (append '("* User-defined additions (variable org-entities-user)")
		      org-entities-user
		      org-entities))
	  (lastwasstring t)
	  (head (concat
		 "\n"
		 "   Symbol   Org entity        LaTeX code             HTML code\n"
		 "   -----------------------------------------------------------\n")))
      (dolist (e ll)
	(pcase e
	  (`(,name ,latex ,_ ,html ,_ ,_ ,utf8)
	   (when lastwasstring
	     (princ head)
	     (setq lastwasstring nil))
	   (princ (format "   %-8s \\%-16s %-22s %-13s\n"
			  utf8 name latex html)))
	  ((pred stringp)
	   (princ e)
	   (princ "\n")
	   (setq lastwasstring t))))))
  (with-current-buffer "*Org Entity Help*"
    (org-mode)
    (when org-pretty-entities
      (org-toggle-pretty-entities)))
  (select-window (get-buffer-window "*Org Entity Help*")))


(provide 'org-entities)

;; Local variables:
;; coding: utf-8
;; End:

;;; org-entities.el ends here
