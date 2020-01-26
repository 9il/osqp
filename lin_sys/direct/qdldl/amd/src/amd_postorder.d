/* ========================================================================= */
/* === AMD_postorder ======================================================= */
/* ========================================================================= */

/* ------------------------------------------------------------------------- */
/* AMD, Copyright (c) Timothy A. Davis,					     */
/* Patrick R. Amestoy, and Iain S. Duff.  See ../README.txt for License.     */
/* email: DrTimothyAldenDavis@gmail.com                                      */
/* ------------------------------------------------------------------------- */

/* Perform a postordering (via depth-first search) of an assembly tree. */

module amd_postorder;

nothrow @nogc extern(C):

import amd_internal;
import amd_post_tree;

void AMD_postorder
(
    /* inputs, not modified on output: */
    Int nn,		/* nodes are in the range 0..nn-1 */
    Int * Parent,	/* Parent [j] is the parent of j, or EMPTY if root */
    Int * Nv,		/* Nv [j] > 0 number of pivots represented by node j,
			 * or zero if j is not a node. */
    Int * Fsize,	/* Fsize [j]: size of node j */

    /* output, not defined on input: */
    Int * Order,	/* output post-order */

    /* workspaces of size nn: */
    Int * Child,
    Int * Sibling,
    Int * Stack
	)
{
    Int i, j, k, parent, frsize, f, fprev, maxfrsize, bigfprev, bigf, fnext ;

    for (j = 0 ; j < nn ; j++)
    {
	Child [j] = EMPTY ;
	Sibling [j] = EMPTY ;
    }

    /* --------------------------------------------------------------------- */
    /* place the children in link lists - bigger elements tend to be last */
    /* --------------------------------------------------------------------- */

    for (j = nn-1 ; j >= 0 ; j--)
    {
	if (Nv [j] > 0)
	{
	    /* this is an element */
	    parent = Parent [j] ;
	    if (parent != EMPTY)
	    {
		/* place the element in link list of the children its parent */
		/* bigger elements will tend to be at the end of the list */
		Sibling [j] = Child [parent] ;
		Child [parent] = j ;
	    }
	}
    }
version(NDEBUG){}
else {
	
    {
	Int nels, ff, nchild ;
	AMD_DEBUG1 (("\n\n================================ AMD_postorder:\n"));
	nels = 0 ;
	for (j = 0 ; j < nn ; j++)
	{
	    if (Nv [j] > 0)
	    {
		//AMD_DEBUG1 (( ""ID" :  nels "ID" npiv "ID" size "ID" parent "ID" maxfr "ID"\n", j, nels,Nv [j], Fsize [j], Parent [j], Fsize [j])) ;	// todo : later
		/* this is an element */
		/* dump the link list of children */
		nchild = 0 ;
		AMD_DEBUG1 (("    Children: ")) ;
		for (ff = Child [j] ; ff != EMPTY ; ff = Sibling [ff])
		{
		    //AMD_DEBUG1 ((ID" ", ff)) ; // todo : later
		    ASSERT (Parent [ff] == j) ;
		    nchild++ ;
		    ASSERT (nchild < nn) ;
		}
		AMD_DEBUG1 (("\n")) ;
		parent = Parent [j] ;
		if (parent != EMPTY)
		{
		    ASSERT (Nv [parent] > 0) ;
		}
		nels++ ;
	    }
	}
    }
    AMD_DEBUG1 (("\n\nGo through the children of each node, and put\nthe biggest child last in each list:\n")) ;
} // !NDEBUG

    /* --------------------------------------------------------------------- */
    /* place the largest child last in the list of children for each node */
    /* --------------------------------------------------------------------- */

    for (i = 0 ; i < nn ; i++)
    {
	if (Nv [i] > 0 && Child [i] != EMPTY)
	{

version(NDEBUG){}
else {
	    Int nchild ;
	    //AMD_DEBUG1 (("Before partial sort, element "ID"\n", i)) ; // todo : later
	    nchild = 0 ;
	    for (f = Child [i] ; f != EMPTY ; f = Sibling [f])
	    {
		ASSERT (f >= 0 && f < nn) ;
		//AMD_DEBUG1 (("      f: "ID"  size: "ID"\n", f, Fsize [f])) ;  // todo : later
		nchild++ ;
		ASSERT (nchild <= nn) ;
	    }
} // !NDEBUG

	    /* find the biggest element in the child list */
	    fprev = EMPTY ;
	    maxfrsize = EMPTY ;
	    bigfprev = EMPTY ;
	    bigf = EMPTY ;
	    for (f = Child [i] ; f != EMPTY ; f = Sibling [f])
	    {
		ASSERT (f >= 0 && f < nn) ;
		frsize = Fsize [f] ;
		if (frsize >= maxfrsize)
		{
		    /* this is the biggest seen so far */
		    maxfrsize = frsize ;
		    bigfprev = fprev ;
		    bigf = f ;
		}
		fprev = f ;
	    }
	    ASSERT (bigf != EMPTY) ;

	    fnext = Sibling [bigf] ;

	    //AMD_DEBUG1 (("bigf "ID" maxfrsize "ID" bigfprev "ID" fnext "ID" fprev " ID"\n", bigf, maxfrsize, bigfprev, fnext, fprev)) ; // todo : later

	    if (fnext != EMPTY)
	    {
		/* if fnext is EMPTY then bigf is already at the end of list */

		if (bigfprev == EMPTY)
		{
		    /* delete bigf from the element of the list */
		    Child [i] = fnext ;
		}
		else
		{
		    /* delete bigf from the middle of the list */
		    Sibling [bigfprev] = fnext ;
		}

		/* put bigf at the end of the list */
		Sibling [bigf] = EMPTY ;
		ASSERT (Child [i] != EMPTY) ;
		ASSERT (fprev != bigf) ;
		ASSERT (fprev != EMPTY) ;
		Sibling [fprev] = bigf ;
	    }

version(NDEBUG){}
else {
	    //AMD_DEBUG1 (("After partial sort, element "ID"\n", i)) ; // todo : later
	    for (f = Child [i] ; f != EMPTY ; f = Sibling [f])
	    {
		ASSERT (f >= 0 && f < nn) ;
		//AMD_DEBUG1 (("        "ID"  "ID"\n", f, Fsize [f])) ; // todo : later
		ASSERT (Nv [f] > 0) ;
		nchild-- ;
	    }
	    ASSERT (nchild == 0) ;
} // !NDEBUG

	}
    }

    /* --------------------------------------------------------------------- */
    /* postorder the assembly tree */
    /* --------------------------------------------------------------------- */

    for (i = 0 ; i < nn ; i++)
    {
	Order [i] = EMPTY ;
    }

    k = 0 ;

    for (i = 0 ; i < nn ; i++)
    {
		if (Parent [i] == EMPTY && Nv [i] > 0)
		{
			version(NDEBUG){
				//AMD_DEBUG1 (("Root of assembly tree "ID"\n", i)) ;  // todo : later
				k = AMD_post_tree (i, k, Child, Sibling, Order, Stack) ;
			}
			else {
				//AMD_DEBUG1 (("Root of assembly tree "ID"\n", i)) ;  // todo : later
				k = AMD_post_tree (i, k, Child, Sibling, Order, Stack, nn) ;
			} // NDEBUG	    
		}
    }
}
