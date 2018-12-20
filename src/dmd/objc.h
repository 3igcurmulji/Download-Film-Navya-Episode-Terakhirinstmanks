
/* Compiler implementation of the D programming language
 * Copyright (C) 2015-2019 by The D Language Foundation, All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/objc.h
 */

#pragma once

#include <stddef.h>

#include "arraytypes.h"

class AggregateDeclaration;
class AttribDeclaration;
class ClassDeclaration;
class FuncDeclaration;
class Identifier;
class InterfaceDeclaration;

struct Scope;

struct ObjcSelector
{
    const char *stringvalue;
    size_t stringlen;
    size_t paramCount;

    static void _init();

    ObjcSelector(const char *sv, size_t len, size_t pcount);

    static ObjcSelector *create(FuncDeclaration *fdecl);
};

struct ObjcClassDeclaration
{
    bool isMeta;
    bool isExtern;

    Identifier* identifier;
    ClassDeclaration* classDeclaration;
    ClassDeclaration* metaclass;
    Dsymbols* methodList;

    bool isRootClass() const;
};

class Objc
{
public:
    static void _init();

    virtual void setObjc(ClassDeclaration* cd) = 0;
    virtual void setObjc(InterfaceDeclaration*) = 0;

    virtual void setSelector(FuncDeclaration*, Scope* sc) = 0;
    virtual void validateSelector(FuncDeclaration* fd) = 0;
    virtual void checkLinkage(FuncDeclaration* fd) = 0;
    virtual bool isVirtual(const FuncDeclaration*) const = 0;
    virtual ClassDeclaration* getParent(FuncDeclaration*, ClassDeclaration*) const = 0;
    virtual void addToClassMethodList(FuncDeclaration*, ClassDeclaration*) const = 0;
    virtual AggregateDeclaration* isThis(FuncDeclaration* fd) = 0;
    virtual VarDeclaration* createSelectorParameter(FuncDeclaration*, Scope*) const = 0;

    virtual void setMetaclass(InterfaceDeclaration* id, Scope*) const = 0;
    virtual void setMetaclass(ClassDeclaration* id, Scope*) const = 0;
    virtual ClassDeclaration* getRuntimeMetaclass(ClassDeclaration* cd) = 0;

    virtual void addSymbols(AttribDeclaration*, ClassDeclarations*, ClassDeclarations*) const = 0;
    virtual void addSymbols(ClassDeclaration*, ClassDeclarations*, ClassDeclarations*) const = 0;
};
