--		Copyright 1994 by Daniel R. Grayson
use tokens;
use parser;
use lex;

-----------------------------------------------------------------------------
-- first, the global symbol table and functions for making symbols
append(buckets:array(SymbolList),word:Word, entry:Symbol):void := (
     h := word.hash & (length(buckets)-1);
     when buckets.h
     is null do buckets.h = SymbolListCell(word,entry,NULL)
     is e:SymbolListCell do (
	  while true do (
	       when e.next 
	       is f:SymbolListCell do e = f
	       is null do (
		    e.next = SymbolListCell(word,entry,NULL);
		    break))));
enlarge(table:SymbolHashTable):void := (
     newbuckets := new array(SymbolList) len 2*length(table.buckets) do provide NULL;
     foreach e in table.buckets do (
	  entryList := e;
	  while true do
	  when entryList
	  is null do break
	  is entryListCell:SymbolListCell do (
	       append(newbuckets, entryListCell.word, entryListCell.entry);
	       entryList = entryListCell.next;
	       )
	  );
     table.buckets = newbuckets;
     );

-- warning: these routines have similar code
export insert(entry:Symbol,table:SymbolHashTable):Symbol := (
     table.numEntries = table.numEntries + 1;
     if 3 * table.numEntries > 2 * length(table.buckets) + 1
     then enlarge(table);
     h := entry.word.hash & (length(table.buckets)-1);
     table.buckets.h = SymbolListCell(entry.word,entry,table.buckets.h);
     entry);
export insert(table:SymbolHashTable, newname:Word, entry:Symbol):Symbol := ( -- warning -- unsafe -- check that the dictionary of the symbol is the same as this dictionary
     table.numEntries = table.numEntries + 1;
     if 3 * table.numEntries > 2 * length(table.buckets) + 1
     then enlarge(table);
     h := newname.hash & (length(table.buckets)-1);
     table.buckets.h = SymbolListCell(newname,entry,table.buckets.h);
     entry);

export makeEntry(word:Word,position:Position,dictionary:Dictionary,thread:bool):Symbol := (
     while dictionary.Protected do (
	  if dictionary == dictionary.outerDictionary then (
	       -- shouldn't occur
	       -- "dictionaries" in actors5.d and "protect" in actors2.d enforce this!
	       error("internal error: global dictionaries all protected");
	       return dummySymbol;
	       );
	  dictionary = dictionary.outerDictionary;
	  );
     frameindex := 0;
     if dictionary.frameID == 0 then (
	  if thread then (
	       -- threadFrame grows whenever an assignment occurs, if needed, so we don't enlarge it now
	       frameindex = threadFramesize;
	       threadFramesize = threadFramesize + 1;
	       )
	  else (
	       -- this allows the global frame to grow
	       frameindex = enlarge(globalFrame)))
     else if dictionary.frameID == localFrame.frameID then (
	  -- This takes care of scopes that span a file or the dictionary for a break loop,
	  -- with a single frame which ought to be allowed to grow.
	  frameindex = enlarge(localFrame) )
     else (
	  -- this is a dynamic frame, not allocated yet
	  frameindex = dictionary.framesize;
	  dictionary.framesize = dictionary.framesize + 1);
     insert(
	  Symbol(
	       word, 
	       nextHash(), 
	       position,
	       dummyUnaryFun,dummyPostfixFun,dummyBinaryFun,
	       dictionary.frameID, 
	       frameindex,
	       1,				-- first lookup is now
	       false,				      -- not protected
	       false,
	       thread
	       ),
	  dictionary.symboltable));
export makeEntry(word:Word,position:Position,dictionary:Dictionary):Symbol := (
     makeEntry(word,position,dictionary,false));
export makeSymbol(word:Word,position:Position,dictionary:Dictionary,thread:bool):Symbol := (
     entry := makeEntry(word,position,dictionary,thread);
     if dictionary.frameID == 0 && isalnum(word.name) && !thread
     then globalFrame.values.(entry.frameindex) = Expr(SymbolClosure(globalFrame,entry));
     entry);
export makeSymbol(word:Word,position:Position,dictionary:Dictionary):Symbol := (
     makeSymbol(word,position,dictionary,false));
export makeProtectedSymbolClosure(w:Word):SymbolClosure := (
     entry := makeSymbol(w,dummyPosition,globalDictionary);
     entry.Protected = true;
     when globalFrame.values.(entry.frameindex)
     is s:SymbolClosure do s
     else SymbolClosure(globalFrame,entry));
makeKeyword(w:Word):SymbolClosure := (
     -- keywords differ from symbols in that their initial value is null
     entry := makeEntry(w,dummyPosition,globalDictionary);
     entry.Protected = true;
     sc := SymbolClosure(globalFrame,entry);
     globalFrame.values.(entry.frameindex) = Expr(sc);
     sc);
export makeProtectedSymbolClosure(s:string):SymbolClosure := makeProtectedSymbolClosure(makeUniqueWord(s,parseWORD));
makeKeyword(s:string):SymbolClosure := makeKeyword(makeUniqueWord(s,parseWORD));
-----------------------------------------------------------------------------
prec := 0;
bump():void := prec = prec + 2;

-- helper functions for setting up words with various methods for parsing them
parseWORD.funs                 = parsefuns(defaultunary, defaultbinary);
unary(s:string)         :Word := install(s,makeUniqueWord(s, parseinfo(prec,nopr  ,prec,parsefuns(unaryop   ,defaultbinary))));
unaryword(s:string)     :Word :=           makeUniqueWord(s, parseinfo(prec,nopr  ,prec,parsefuns(unaryop   ,defaultbinary)));
biunary(s:string)       :Word := install(s,makeUniqueWord(s, parseinfo(prec,nopr  ,prec,parsefuns(unaryop   ,postfixop))));
postfix(s:string)       :Word := install(s,makeUniqueWord(s, parseinfo(prec,nopr  ,nopr,parsefuns(errorunary,postfixop))));
unarybinaryleft(s:string)     :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec  ,prec,parsefuns(unaryop   ,binaryop))));
unarybinaryright(s:string)    :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec-1,prec,parsefuns(unaryop   ,binaryop))));
binaryleft(s:string)    :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec  ,nopr,parsefuns(errorunary,binaryop))));
binaryleftword(s:string):Word :=           makeUniqueWord(s, parseinfo(prec,prec  ,nopr,parsefuns(errorunary,binaryop)));
nleft (s:string)        :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec  ,nopr,parsefuns(errorunary,nbinaryop))));
nright(s:string)        :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec-1,nopr,parsefuns(errorunary,nbinaryop))));
nleftword(s:string)     :Word :=           makeUniqueWord(s, parseinfo(prec,prec  ,nopr,parsefuns(errorunary,nbinaryop)));
nunarybinaryleft(s:string)    :Word := install(s,makeUniqueWord(s, parseinfo(prec,prec  ,prec,parsefuns(nnunaryop ,nbinaryop))));
token(s:string)         :Word :=           makeUniqueWord(s, parseinfo(prec,nopr  ,prec,parsefuns(errorunary,errorbinary)));
binaryright(s:string,binary:function(ParseTree,Token,TokenFile,int,bool):ParseTree):Word
                              := install(s,makeUniqueWord(s, parseinfo(prec,prec-1,nopr,parsefuns(errorunary,binary))));
binaryrightword(s:string):Word:=           makeUniqueWord(s, parseinfo(prec,prec-1,nopr,parsefuns(errorunary,binaryop)));
binaryright(s:string)   :Word := binaryright(s,binaryop);
parens(left:string,right:string,leftprec:int,rightprec:int,unaryStrength:int):Word := (
     l := makeUniqueWord(left,
	  parseinfo(leftprec ,nopr,unaryStrength,parsefuns(unaryparen, defaultbinary)));
     r := makeUniqueWord(right,
          parseinfo(rightprec,nopr,nopr,         parsefuns(errorunary, errorbinary  )));
     left = l.name;
     right = r.name;
     install(left,l);
     install(right,r);
     addmatch(left,right);
     makeKeyword(l);
     makeKeyword(r);
     l);
special(s:string,f:function(Token,TokenFile,int,bool):ParseTree,lprec:int,rprec:int):SymbolClosure := (
     makeKeyword(makeUniqueWord(s, parseinfo(lprec, nopr, rprec, parsefuns(f, defaultbinary)))));

-- Now the symbols and operators:

-- Keep in mind that a "Word" is determined by a string token, and has attributes 
-- that determine how it is parsed, but a "Symbol" or "SymbolClosure" is a Word together
-- with a binding done in a particular way depending on the current dictionary.  The symbols
-- created below are all in the global dictionary.

-- new operators must be:
--   set up as an "actor" with "setup()"
--   added to the export list in ../m2/exports.m2
--   added to the table binaryOperatorFunctions in ../m2/expressions.m2
--   added to the list of operators in the documentation node "operators" in ../packages/Macaulay2Doc/ov_language.m2
--   documented with a suitable headline, such as:
--     	    "a unary operator"
--     	    "a binary operator"
--     	    "a unary and binary operator"
--     	    "a unary postfix operator"

bump();
     wordEOF = nleftword("{*end of file*}");
     makeKeyword(wordEOF);
bump();
     wordEOC = nleftword("{*end of cell*}");
     makeKeyword(wordEOC);
bump();
     precRightParen := prec;
bump();
     export SemicolonW := nright(";");
     export SemicolonS := makeKeyword(SemicolonW);
     NewlineW = nleftword("{*newline*}");
bump();
     export CommaW := nunarybinaryleft(","); export commaS := makeKeyword(CommaW);
bump();
     wide := prec;
     elseW = token("else"); makeKeyword(elseW);
     thenW = token("then"); makeKeyword(thenW);
     doW = token("do"); makeKeyword(doW);
     listW = token("list"); makeKeyword(listW);
bump();
     export ColonEqualW := binaryright(":="); export ColonEqualS := makeKeyword(ColonEqualW);
     export EqualW := binaryright("="); export EqualS := makeKeyword(EqualW);
     export LeftArrowW := binaryright("<-"); export LeftArrowS := makeKeyword(LeftArrowW);
     export RightArrowW := binaryright("->",arrowop); export RightArrowS := makeKeyword(RightArrowW);
     export DoubleArrowS := makeKeyword(binaryright("=>"));
     export GreaterGreaterS := makeKeyword(binaryright(">>"));
bump();
     whenW = token("when"); makeKeyword(whenW);
     ofW = token("of"); makeKeyword(ofW);
     inW = token("in"); makeKeyword(inW);
     fromW = token("from"); makeKeyword(fromW);
     toW = token("to"); makeKeyword(toW);
     narrow := prec;
bump();
     export LessLessS := makeKeyword(unarybinaryleft("<<"));	    -- also binary
bump();
     export DeductionS := makeKeyword(unarybinaryright("|-"));	    -- also binary
bump();
     export LongLongDoubleRightArrowS := makeKeyword(binaryright("===>"));
     export LongLongDoubleLeftArrowS := makeKeyword(unarybinaryright("<==="));
bump();
     export LongBiDoubleArrowS := makeKeyword(binaryright("<==>"));
bump();
     export LongDoubleRightArrowS := makeKeyword(binaryright("==>"));
     export LongDoubleLeftArrowS := makeKeyword(unarybinaryright("<==")); -- also binary
bump();
     export orS := makeKeyword(binaryrightword("or"));
bump();
     export andS := makeKeyword(binaryrightword("and"));
bump();
     export notS := makeKeyword(unaryword("not"));
-- binary predicates on terms:
bump();
     export incomparableS := makeProtectedSymbolClosure("incomparable");
     export LessS := makeKeyword(unarybinaryright("<"));
     export GreaterS := makeKeyword(unarybinaryright(">"));
     export LessEqualS := makeKeyword(unarybinaryright("<="));
     export GreaterEqualS := makeKeyword(unarybinaryright(">="));
     export EqualEqualEqualS := makeKeyword(binaryright("==="));
     export EqualEqualS := makeKeyword(binaryright("=="));
     export QuestionS := makeKeyword(unarybinaryright("?"));
     export NotEqualEqualEqualS := makeKeyword(binaryright("=!="));
     export NotEqualS := makeKeyword(binaryright("!="));
-- operations on terms that yield terms:
bump();
     export BarBarS := makeKeyword(binaryleft("||"));
bump();
     export ColonS := makeKeyword(binaryright(":"));
bump();
     export BarS := makeKeyword(binaryleft("|"));
bump();
     export HatHatS := makeKeyword(binaryleft("^^"));
bump();
     export AmpersandS := makeKeyword(binaryleft("&"));
bump();
     export DotDotS := makeKeyword(binaryleft(".."));
     export DotDotLessS := makeKeyword(binaryleft("..<"));
bump();
     export MinusS := makeKeyword(unarybinaryleft("-"));	    -- also binary
     export PlusS := makeKeyword(unarybinaryleft("+"));	    -- also binary
     export PlusPlusS := makeKeyword(binaryleft("++"));
bump();
     export StarStarS := makeKeyword(binaryleft("**"));
bump();
     precBracket := prec;
     export leftbracket := parens("[","]",precBracket, precRightParen, precRightParen);
bump();
     export BackslashBackslashS := makeKeyword(binaryright("\\\\"));
     export StarS := makeKeyword(unarybinaryleft("*"));	    -- also binary
     export DivideS := makeKeyword(binaryleft("/"));
     export LeftDivideS := makeKeyword(binaryright("\\"));
     export PercentS := makeKeyword(binaryleft("%"));
     export SlashSlashS := makeKeyword(binaryleft("//"));
bump();
     export AtS := makeKeyword(binaryright("@"));
bump();
     precSpace = prec;
     export AdjacentS:=makeKeyword(binaryright("SPACE"));
     export leftparen   := parens("(",")",precSpace, precRightParen, precRightParen);
     export leftbrace   := parens("{","}",precSpace, precRightParen, precRightParen);
     parseWORD.precedence = prec; parseWORD.binaryStrength = nopr; parseWORD.unaryStrength = nopr;
     export timeS := special("time",unaryop,precSpace,wide);
     export timingS := special("timing",unaryop,precSpace,wide);
     export shieldS := special("shield",unaryop,precSpace,wide);
     export throwS := special("throw",nunaryop,precSpace,wide);
     export returnS := special("return",nunaryop,precSpace,wide);
     export breakS := special("break",nunaryop,precSpace,wide);
     export continueS := special("continue",nunaryop,precSpace,wide);
     export stepS := special("step",nunaryop,precSpace,wide);
     -- export codePositionS := special("codePosition",unaryop,precSpace,narrow);
     special("new",unarynew,precSpace,narrow);
     special("for",unaryfor,precSpace,narrow);
     special("while",unarywhile,precSpace,wide);
     special("if",unaryif,precSpace,wide);
     special("try",unarytry,precSpace,wide);
     special("catch",unarycatch,precSpace,wide);
bump();
     export ParenStarParenS := makeKeyword(postfix("(*)"));
bump();
     export AtAtS := makeKeyword(binaryleft("@@"));
bump();
     export TildeS := makeKeyword(postfix("~"));
     export UnderscoreStarS := makeKeyword(postfix("_*"));
     export PowerStarS := makeKeyword(postfix("^*"));
bump();
     export PowerS := makeKeyword(binaryleft("^"));
     export PowerStarStarS := makeKeyword(binaryleft("^**"));
     export UnderscoreS := makeKeyword(binaryleft("_"));
     export SharpS := makeKeyword(unarybinaryleft("#")); SharpS.symbol.word.parse.unaryStrength = precSpace-1;
     export SharpQuestionS := makeKeyword(binaryleft("#?"));
     export DotS := makeKeyword(binaryleft("."));
     export DotQuestionS := makeKeyword(binaryleft(".?"));
bump();
     export ExclamationS := makeKeyword(postfix("!"));
bump();
     special("symbol",unarysymbol,precSpace,prec);
     special("global",unaryglobal,precSpace,prec);
     special("threadVariable",unarythread,precSpace,prec);
     special("local",unarylocal,precSpace,prec);
-----------------------------------------------------------------------------
export GlobalAssignS := makeProtectedSymbolClosure("GlobalAssignHook");
export GlobalAssignE := Expr(GlobalAssignS);

export GlobalReleaseS := makeProtectedSymbolClosure("GlobalReleaseHook");
export GlobalReleaseE := Expr(GlobalReleaseS);

export EqualE := Expr(EqualS);
export LeftArrowE := Expr(LeftArrowS);

export EqualEqualE := Expr(EqualEqualS);
export LessE := Expr(LessS);
export GreaterE := Expr(GreaterS);
export incomparableE := Expr(incomparableS);

export NewS := makeProtectedSymbolClosure("NewMethod");
export NewE := Expr(NewS);

export NewOfS := makeProtectedSymbolClosure("NewOfMethod");
export NewOfE := Expr(NewOfS);

export NewFromS := makeProtectedSymbolClosure("NewFromMethod");
export NewFromE := Expr(NewFromS);

export NewOfFromS := makeProtectedSymbolClosure("NewOfFromMethod");
export NewOfFromE := Expr(NewOfFromS);

export InverseS := makeProtectedSymbolClosure("InverseMethod");
export InverseE := Expr(InverseS);
-----------------------------------------------------------------------------
export makeSymbol(t:Token):Symbol := (
     e := makeSymbol(t.word,position(t),t.dictionary);
     t.entry = e;
     e);
HadError := false;
export makeErrorTree(e:ParseTree,message:string):void := (
     HadError = true;
     printErrorMessage(treePosition(e),message);
     );
export makeErrorTree(e:Token,message:string):void := (
     HadError = true;
     printErrorMessage(e,message);
     );
makeSymbol(e:ParseTree,dictionary:Dictionary):void := (
     when e
     is token:Token do (
	  token.dictionary = dictionary;
	  makeSymbol(token);)
     else makeErrorTree(e,"expected single identifier"));
-----------------------------------------------------------------------------
lookupCountIncrement := 1;
export lookup(word:Word,table:SymbolHashTable):(null or Symbol) := (
     if table == dummySymbolHashTable then error("dummy symbol table used");
     entryList := table.buckets.(
	  word.hash & (length(table.buckets)-1)
	  );
     while true do
     when entryList
     is null do return NULL
     is entryListCell:SymbolListCell do (
	  if entryListCell.word == word 
	  then (
	       e := entryListCell.entry;
	       e.lookupCount = e.lookupCount + lookupCountIncrement;
	       return e;
	       );
	  entryList = entryListCell.next));

export globalLookup(w:Word):(null or Symbol) := (
     d := globalDictionary;
     while (
	  when lookup(w,d.symboltable) is null do nothing is e:Symbol do return e;
	  d != d.outerDictionary ) do d = d.outerDictionary;
     NULL);
export lookup(w:Word,d:Dictionary):(null or Symbol) := (
     while (
	  when lookup(w,d.symboltable) is null do nothing is e:Symbol do return e;
	  d != d.outerDictionary ) do d = d.outerDictionary;
     globalLookup(w));
lookup(t:Token,forcedef:bool,thread:bool):void := (
     n := length(t.word.name);
     if n >= 1 && isdigit(t.word.name.0) 
     || n >= 2 && t.word.name.0 == '.' && isdigit(t.word.name.1)
     then nothing
     else (
     	  when lookup(t.word,t.dictionary)
     	  is entry:Symbol do (
	       t.entry = entry;
	       if entry.flagLookup then (
		    printErrorMessage(t,"flagged symbol encountered");
		    HadError=true;
		    );
	       if thread && !entry.thread then (
		    printErrorMessage(t,"symbol already present, but not thread local");
		    HadError=true;
		    );
	       )
     	  else (
	       if forcedef
	       then (
		    t.dictionary = globalDictionary; -- undefined variables are defined as global
	       	    t.entry = makeSymbol(t.word,position(t),globalDictionary,thread);
		    )
	       else (
	       	    printErrorMessage(t,"undefined symbol " + t.word.name);
	       	    HadError=true;))));
lookup(t:Token):void := lookup(t,true,false);
lookuponly(t:Token):void := lookup(t,false,false);
-----------------------------------------------------------------------------
export opsWithBinaryMethod := array(SymbolClosure)(
     LessLessS, GreaterGreaterS, EqualEqualS, QuestionS, BarBarS, 
     LongBiDoubleArrowS, DeductionS,
     LongDoubleRightArrowS, LongLongDoubleRightArrowS,
     LongDoubleLeftArrowS, LongLongDoubleLeftArrowS,
     ColonS, BarS, HatHatS, AmpersandS, DotDotS, DotDotLessS, MinusS, PlusS, PlusPlusS, StarStarS, StarS, BackslashBackslashS, DivideS, LeftDivideS, PercentS, SlashSlashS, AtS, 
     AdjacentS, AtAtS, PowerS, UnderscoreS, PowerStarStarS, orS, andS);
export opsWithUnaryMethod := array(SymbolClosure)(
     StarS, MinusS, PlusS, LessLessS, 
     LongDoubleLeftArrowS, LongLongDoubleLeftArrowS, 
     notS, DeductionS, QuestionS,LessS,GreaterS,LessEqualS,GreaterEqualS);
export opsWithPostfixMethod := array(SymbolClosure)( TildeS, ParenStarParenS, UnderscoreStarS, PowerStarS ,ExclamationS );

-- ":=" "=" "<-" "->"  "=>" "===" "=!=" "!=" "#" "#?" "." ".?" ";" "," "<" ">" "<=" ">="
export fixedBinaryOperators := array(SymbolClosure)(ColonEqualS,EqualS,LeftArrowS,RightArrowS,DoubleArrowS,EqualEqualEqualS,NotEqualEqualEqualS,NotEqualS,SharpS,SharpQuestionS,
     DotS,DotQuestionS,SemicolonS,commaS,LessS,GreaterS,LessEqualS,GreaterEqualS);

-- "#" "," "<" ">" "<=" ">="
export fixedPrefixOperators := array(SymbolClosure)(commaS,SharpS);

-- ";" ","
export fixedPostfixOperators := array(SymbolClosure)(SemicolonS,commaS);

-----------------------------------------------------------------------------
bind(t:Token,dictionary:Dictionary):void := (
     t.dictionary = dictionary;
     lookup(t););
bindThread(t:Token,dictionary:Dictionary):void := (
     t.dictionary = dictionary;
     lookup(t,true,true););
bindop(t:Token,dictionary:Dictionary):void := (
     t.dictionary = dictionary;
     lookuponly(t););
bind(e:ParseTree,dictionary:Dictionary):void;
bindFormalParm(e:ParseTree,dictionary:Dictionary,desc:functionDescription):void := (
     when e
     is t:Token do (
	  if t.word.typecode == TCid then makeSymbol(e,dictionary)
	  else makeErrorTree(t,"expected symbol");
	  desc.numparms = desc.numparms + 1;
	  )
     else makeErrorTree(e,"syntax error: expected function parameter"));
bindFormalParmList(e:ParseTree,dictionary:Dictionary,desc:functionDescription):void := (
     when e 
     is binary:Binary do (
	  if binary.Operator.word == CommaW
	  then (
	       bindFormalParmList(binary.lhs,dictionary,desc);
	       bindop(binary.Operator,dictionary);
	       bindFormalParm(binary.rhs,dictionary,desc);)
	  else makeErrorTree(e,"syntax error: expected function parameter list"))
     else bindFormalParm(e,dictionary,desc));
bindSingleParm(e:ParseTree,dictionary:Dictionary):void := (
     when e 
     is t:Token do (
	  if t.word.typecode == TCid then makeSymbol(e,dictionary)
	  else makeErrorTree(t,"expected symbol")
	  )
     else makeErrorTree(e,"expected symbol"));
bindParenParmList(e:ParseTree,dictionary:Dictionary,desc:functionDescription):void := (
     when e 
     is t:Token do (
	  bindFormalParm(e,dictionary,desc);
	  desc.restargs = true;
	  )
     is p:Parentheses do (
	  bindFormalParmList(p.contents,dictionary,desc)
	  )
     is p:EmptyParentheses do nothing
     else makeErrorTree(e,"expected parenthesized argument list or symbol"));
opHasBinaryMethod(o:Symbol):bool := (
     foreach s in opsWithBinaryMethod do if s.symbol == o then return true;
     return false;
     );
opHasUnaryMethod(o:Symbol):bool := (
     foreach s in opsWithUnaryMethod do if s.symbol == o then return true;
     return false;
     );
opHasPostfixMethod(o:Symbol):bool := (
     foreach s in opsWithPostfixMethod do if s.symbol == o then return true;
     return false;
     );
bindTokenLocally(t:Token,dictionary:Dictionary):void := (
     lookupCountIncrement = 0;
     r := lookup(t.word,dictionary);
     lookupCountIncrement = 1;
     when r
     is entry:Symbol do (
	  if dictionary.frameID == entry.frameID
	  then printWarningMessage(t, "local declaration of " + t.word.name + " shields variable with same name" );
	  )
     else nothing;
     t.dictionary = dictionary;
     makeSymbol(t);
     );
bindToken(t:Token,dictionary:Dictionary,colon:bool):void := (
     if colon then bindTokenLocally(t,dictionary) else bind(t,dictionary);
     );
bindParallelAssignmentItem(e:ParseTree,dictionary:Dictionary,colon:bool):void := (
     when e
     is token:Token do (
	  if token.word.typecode != TCid then makeErrorTree(token,"syntax error: parallel assignment expected symbol")
	  else bindToken(token,dictionary,colon);
	  )
     else makeErrorTree(e,"syntax error: parallel assignment expected symbol"));
bindParallelAssignmentList(e:ParseTree,dictionary:Dictionary,colon:bool):void := (
     when e
     is binary:Binary do (
	  if binary.Operator.word == CommaW
	  then (
	       bindParallelAssignmentList(binary.lhs,dictionary,colon);
	       bindop(binary.Operator,dictionary);
	       bindParallelAssignmentItem(binary.rhs,dictionary,colon);
	       )
     	  else makeErrorTree(e,"syntax error: parallel assignment expected symbol list")
	  )
     else bindParallelAssignmentItem(e,dictionary,colon));
bindassignment(assn:Binary,dictionary:Dictionary,colon:bool):void := (
     bindop(assn.Operator,dictionary);
     body := assn.rhs;
     when assn.lhs
     is p:Parentheses do (
	  bindParallelAssignmentList(p.contents,dictionary,colon);
	  bind(body,dictionary);
	  )
     is token:Token do (
	  if token.word.typecode != TCid then (
	       makeErrorTree(assn.Operator, "expected a symbol to left of '"+assn.Operator.entry.word.name+"'");
	       return;
	       );
	  bindToken(token,dictionary,colon);
	  bind(body,dictionary);
	  )
     is a:Adjacent do (
	  bind(a.lhs,dictionary);
	  bind(a.rhs,dictionary);
	  bind(body,dictionary);
	  )
     is unary:Unary do (
	  bindop(unary.Operator,dictionary);
	  bind(unary.rhs,dictionary);
	  bind(body,dictionary);
	  if colon
	  then (
	       if ! opHasUnaryMethod(unary.Operator.entry)
	       then makeErrorTree(assn.Operator, "can't assign a method for this unary operator");
	       )
	  else (
	       if ! opHasUnaryMethod(unary.Operator.entry)
	       then makeErrorTree(assn.Operator, "can't assign a value for this unary operator")
	       )
	  )
     is unary:Postfix do (
	  bind(unary.lhs,dictionary);
	  bindop(unary.Operator,dictionary);
	  bind(body,dictionary);
	  if colon
	  then (
	       if ! opHasPostfixMethod(unary.Operator.entry)
	       then makeErrorTree(assn.Operator, "can't assign a method for this postfix operator");
	       )
	  else (
	       if ! opHasPostfixMethod(unary.Operator.entry)
	       then makeErrorTree(assn.Operator, "can't assign a value for this postfix operator")
	       )
	  )
     is binary:Binary do (
	  bind(binary.lhs,dictionary);
	  bindop(binary.Operator,dictionary);
	  bind(binary.rhs, if binary.Operator.word == DotS.symbol.word then globalDictionary else dictionary );
	  bind(body,dictionary);
	  if colon then (
	       if ! opHasBinaryMethod(binary.Operator.entry)
	       then makeErrorTree( assn.Operator, "can't assign a method for this binary operator");
	       )
	  else (
	       if !(binary.Operator.word == DotS.symbol.word
		    || 
		    binary.Operator.word == SharpS.symbol.word
		    ||
		    opHasBinaryMethod(binary.Operator.entry))
	       then makeErrorTree( assn.Operator, "can't assign a value for this binary operator");
	       if binary.Operator.word == DotS.symbol.word then (
		    when binary.rhs is t:Token do (
			 if t.word.typecode != TCid
			 then makeErrorTree(assn.Operator, "expected a symbol to right of '.'");
			 )
		    else makeErrorTree(assn.Operator, "expected a symbol to right of '.'");
		    );
	       )
	  )
     is n:New do (
	  if colon then (
	       bind(n.newclass,dictionary);
	       bind(n.newparent,dictionary);
	       bind(n.newinitializer,dictionary);
	       bind(body,dictionary))
	  else makeErrorTree(assn.Operator, 
	       "left hand side of assignment inappropriate"))
     else makeErrorTree(assn.Operator, 
	  "left hand side of assignment inappropriate"));
bindnewdictionary(e:ParseTree,dictionary:Dictionary):ParseTree := (
     n := newLocalDictionary(dictionary);
     bind(e,n);
     ParseTree(StartDictionary(n,e)));
export bind(e:ParseTree,dictionary:Dictionary):void := (
     when e
     is s:StartDictionary do bind(s.body,dictionary)
     is i:IfThen do (
	  bind(i.predicate,dictionary);
	  -- i.thenclause = bindnewdictionary(i.thenclause,dictionary);
	  bind(i.thenclause,dictionary);
	  )
     is i:IfThenElse do (
	  bind(i.predicate,dictionary);
	  -- i.thenclause = bindnewdictionary(i.thenclause,dictionary);
	  bind(i.thenclause,dictionary);
	  -- i.elseClause = bindnewdictionary(i.elseClause,dictionary);
	  bind(i.elseClause,dictionary);
	  )
     is token:Token do (
	  if token.word.typecode == TCid then bind(token,dictionary);
	  )
     is adjacent:Adjacent do (
	  bind(adjacent.lhs,dictionary); 
	  bind(adjacent.rhs,dictionary))
     is binary:Binary do (
	  if binary.Operator.word == EqualW
	  then bindassignment(binary,dictionary,false)
	  else if binary.Operator.word == ColonEqualW
	  then bindassignment(binary,dictionary,true)
	  else if binary.Operator.word == DotS.symbol.word
	  then (
	       bind(binary.lhs,dictionary);
	       bindop(binary.Operator,dictionary);
	       bind(binary.rhs,globalDictionary);
	       when binary.rhs
	       is token:Token do (
		    if token.word.typecode != TCid
		    then makeErrorTree(binary.Operator, "expected a symbol to right of '.'" );
		    )
	       else makeErrorTree(binary.Operator, "expected a symbol to right of '.'" );
	       )
	  else if binary.Operator.word == DotQuestionS.symbol.word
	  then (
	       bind(binary.lhs,dictionary);
	       bindop(binary.Operator,dictionary);
	       bind(binary.rhs,globalDictionary);
	       when binary.rhs
	       is token:Token do (
		    if token.word.typecode != TCid
		    then makeErrorTree(binary.Operator, "expected a symbol to right of '.?'" );
		    )
	       else makeErrorTree(binary.Operator, "expected a symbol to right of '.?'" );
	       )
	  else (
	       bind(binary.lhs,dictionary);
	       bindop(binary.Operator,dictionary);
	       bind(binary.rhs,dictionary);
	       );
	  )
     is q:LocalQuote do (
	  bind(q.Operator,dictionary);
	  tok := q.rhs;
	  tok.dictionary = dictionary;
	  r := lookup(tok.word,dictionary.symboltable);
	  when r
	  is entry:Symbol do ( tok.entry = entry; )
	  else ( makeSymbol(tok); );
	  )
     is q:GlobalQuote do (
	  bind(q.Operator,dictionary);
	  bind(q.rhs,globalDictionary);
	  )
     is q:ThreadQuote do (
	  bind(q.Operator,dictionary);
	  bindThread(q.rhs,globalDictionary);
	  )
     is q:Quote do (
	  bind(q.Operator,dictionary);
	  bind(q.rhs,dictionary);
	  )
     is a:Arrow do (
	  newdict := newLocalDictionary(dictionary);
	  a.desc = functionDescription(newdict.frameID,0,0,false);
	  bindParenParmList(a.lhs,newdict,a.desc);
	  bind(a.rhs,newdict);
	  a.desc.framesize = newdict.framesize;
	  )
     is unary:Unary do (
	  bindop(unary.Operator,dictionary);
	  bind(unary.rhs,dictionary);)
     is postfix:Postfix do (
	  bind(postfix.lhs,dictionary);
	  bindop(postfix.Operator,dictionary);)
     is ee:Parentheses do bind(ee.contents,dictionary)
     is EmptyParentheses do nothing
     is dummy do nothing
     is w:WhileDo do (
	  bind(w.predicate,dictionary);
	  -- w.body = bindnewdictionary(w.body,dictionary);
	  bind(w.doClause,dictionary);
	  )
     is w:For do (
	  newdict := newLocalDictionary(dictionary);
	  bindSingleParm(w.variable,newdict);
	  bind(w.inClause,dictionary);
	  bind(w.fromClause,dictionary);
	  bind(w.toClause,dictionary);
	  bind(w.whenClause,newdict);
	  bind(w.listClause,newdict);
	  bind(w.doClause,newdict);
	  w.dictionary = newdict;
	  )
     is w:WhileList do (
	  bind(w.predicate,dictionary);
	  bind(w.listClause,dictionary);
	  )
     is w:WhileListDo do (
	  bind(w.predicate,dictionary);
	  bind(w.listClause,dictionary);
	  bind(w.doClause,dictionary);
	  )
     is n:New do (
     	  bind(n.newclass,dictionary);
     	  bind(n.newparent,dictionary);
     	  bind(n.newinitializer,dictionary);)
     is i:TryElse do (
	  -- i.primary = bindnewdictionary(i.primary,dictionary);
	  bind(i.primary,dictionary);
	  -- i.alternate = bindnewdictionary(i.alternate,dictionary);
	  bind(i.alternate,dictionary);
	  )
     is i:TryThenElse do (
	  bind(i.primary,dictionary);
	  bind(i.sequel,dictionary);
	  bind(i.alternate,dictionary);
	  )
     is i:Try do (
	  bind(i.primary,dictionary);
	  )
     is i:Catch do (
	  bind(i.primary,dictionary);
	  )
     );
export localBind(e:ParseTree,dictionary:Dictionary):bool := (
     HadError = false;
     bind(e,dictionary);
     !HadError
     );

-- Local Variables:
-- compile-command: "echo \"make: Entering directory \\`$M2BUILDDIR/Macaulay2/d'\" && make -C $M2BUILDDIR/Macaulay2/d binding.o "
-- End: